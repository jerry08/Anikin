using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AniStream.Services;
using AniStream.Utils;
using AniStream.ViewModels.Framework;
using AniStream.Views.BottomSheets;
using Berry.Maui;
using Berry.Maui.Core;
using Berry.Maui.Core.Primitives;
using Berry.Maui.Views;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Juro.Core.Providers;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;
using Media = Jita.AniList.Models.Media;

namespace AniStream.ViewModels;

public partial class VideoPlayerViewModel : BaseViewModel
{
    private readonly PlayerSettings _playerSettings = new();
    private readonly DisplayOrientation _initialOrientation;

    private readonly IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();

    private readonly Media _media;
    private readonly IAnimeInfo _anime;
    private readonly Episode _episode;
    private readonly VideoSource? _video;

    public Episode? PreviousEpisode { get; private set; }

    public Episode? NextEpisode { get; private set; }

    private PlatformMediaController Controller { get; set; } = default!;
    private IMediaElement MediaElement { get; set; } = default!;

    private bool CanSaveProgress { get; set; }

    [ObservableProperty]
    private bool _startedPlaying;

    public string EpisodeKey { get; set; }

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    [ObservableProperty]
    private MediaSource? _source;

    public VideoPlayerViewModel(IAnimeInfo anime, Episode episode, VideoSource? video, Media media)
    {
        _anime = anime;
        _episode = episode;
        _video = video;
        _media = media;
        _initialOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;

        IsBusy = true;

        _playerSettings.Load();

        SetCurrent();
    }

    public VideoPlayerViewModel(IAnimeInfo anime, Episode episode, Media media)
        : this(anime, episode, null, media) { }

    public void SetCurrent()
    {
        var index = EpisodeViewModel.Episodes.OrderBy(x => x.Number).ToList()
            .IndexOf(_episode);

        PreviousEpisode = EpisodeViewModel.Episodes.OrderBy(x => x.Number)
            .ElementAtOrDefault(index - 1);

        NextEpisode = EpisodeViewModel.Episodes.OrderBy(x => x.Number)
            .ElementAtOrDefault(index + 1);

        EpisodeKey = $"{_media.Id}-{_episode.Number}";
    }

    [RelayCommand]
    public void OnLoaded(IMediaElement mediaElement)
    {
        Shell.Current.Navigating += Current_Navigating;

        MediaElement = mediaElement;
        Controller = new(this, _anime, _episode, default!, _media);
        Controller.OnLoaded(mediaElement);
    }

    private void Current_Navigating(object? sender, ShellNavigatingEventArgs e)
    {
        _cancellationTokenSource.Cancel();
        UpdateProgress();
    }

    [RelayCommand]
    private void OnUnloaded()
    {
        Shell.Current.Navigating -= Current_Navigating;

        Controller.Dispose();

        ApplicationEx.SetOrientation(_initialOrientation);
    }

    [RelayCommand]
    private void OnStateChanged(MediaElementState state)
    {
        switch (state)
        {
            case MediaElementState.None:
                break;
            case MediaElementState.Opening:
                break;
            case MediaElementState.Buffering:
                break;
            case MediaElementState.Playing:
                StartedPlaying = true;
                CanSaveProgress = true;
                break;
            case MediaElementState.Paused:
                UpdateProgress();
                break;
            case MediaElementState.Stopped:
                UpdateProgress();
                break;
            case MediaElementState.Failed:
                CanSaveProgress = false;
                break;
            default:
                break;
        }
    }

    public async Task ShowSpeedSelector()
    {
        var speeds = _playerSettings.GetSpeeds();
        var speedsName = speeds.Select(x => $"{x}x").ToList();

        var speedName = await Shell.Current.DisplayActionSheet(
            "Playback Speed",
            "",
            "",
            speedsName.ToArray()
        );
        if (string.IsNullOrWhiteSpace(speedName))
            return;

        var speedIndex = speedsName.IndexOf(speedName);
        if (speedIndex <= 0)
            return;

        MediaElement.Speed = speeds[speedIndex];

        await Toast.Make($"Playing at {speedName} speed").Show();
    }

    protected override async Task LoadCore()
    {
        IsBusy = true;

        try
        {
            var video = _video ?? await GetVideoAsync();
            if (video is null)
                return;

            var source = (UriMediaSource)MediaSource.FromUri(video.VideoUrl)!;
            source.UserAgent =
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36";
            source.Headers = video.Headers;

            Source = source;

#if ANDROID
            // This runs after source is created and attached to exoplayer
            Controller.Initialize();
#endif

            _playerSettings.WatchedEpisodes.TryGetValue(EpisodeKey, out var watchedEpisode);

            if (watchedEpisode is not null)
                MediaElement.SeekTo(TimeSpan.FromMilliseconds(watchedEpisode.WatchedDuration));
        }
        catch (Exception ex)
        {
            if (!CancellationToken.IsCancellationRequested)
            {
                await App.AlertService.ShowAlertAsync("Error", ex.ToString());
            }
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task<VideoSource?> GetVideoAsync()
    {
        var videoServer = await GetVideoServerAsync();
        if (videoServer is null)
        {
            await Toast.Make("No servers found").Show();
            return null;
        }

        var videos = await _provider.GetVideosAsync(videoServer, CancellationToken);
        if (videos.Count == 0)
        {
            await Toast.Make("No videos found").Show();
            await ShowSheet();
            return null;
        }

        return videos[0];
    }

    private async Task<VideoServer?> GetVideoServerAsync()
    {
        var videoServers = await _provider.GetVideoServersAsync(_episode.Id, CancellationToken);
        if (videoServers.Count == 0)
            return null;

        return videoServers.Find(
                x =>
                    x.Name?.ToLower().Contains("streamsb") == true
                    || x.Name?.ToLower().Contains("vidstream") == true
                    || x.Name?.Equals("mirror", StringComparison.OrdinalIgnoreCase) == true // Indonesian
            ) ?? videoServers[0];
    }

    async Task ShowSheet()
    {
        var sheet = new VideoSourceSheet();
        sheet.BindingContext = new VideoSourceViewModel(sheet, _anime, _episode, _media);

        await sheet.ShowAsync();
    }

    public void UpdateProgress()
    {
        if (!CanSaveProgress)
            return;

        _playerSettings.WatchedEpisodes.TryGetValue(EpisodeKey, out var watchedEpisode);

        watchedEpisode ??= new();

        watchedEpisode.Id = EpisodeKey;
        watchedEpisode.AnimeName = _anime.Title;
        watchedEpisode.WatchedPercentage =
            (float)MediaElement.Position.TotalMilliseconds
            / (float)MediaElement.Duration.TotalMilliseconds
            * 100f;
        watchedEpisode.WatchedDuration = (long)MediaElement.Position.TotalMilliseconds;

        _playerSettings.WatchedEpisodes.Remove(EpisodeKey);
        _playerSettings.WatchedEpisodes.Add(EpisodeKey, watchedEpisode);

        _playerSettings.Save();
    }
}
