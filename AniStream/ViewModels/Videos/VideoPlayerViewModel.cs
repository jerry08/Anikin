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

    public Media Media { get; private set; }
    public IAnimeInfo Anime { get; private set; }
    public VideoSource? Video { get; set; }

    public Episode Episode { get; private set; }

    public Episode? PreviousEpisode { get; private set; }

    public Episode? NextEpisode { get; private set; }

    private PlatformMediaController Controller { get; set; } = default!;
    private IMediaElement MediaElement { get; set; } = default!;

    private bool CanSaveProgress { get; set; }

    [ObservableProperty]
    private bool _startedPlaying;

    public string EpisodeKey { get; set; } = default!;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    [ObservableProperty]
    private MediaSource? _source;

    public VideoPlayerViewModel(IAnimeInfo anime, Episode episode, VideoSource? video, Media media)
    {
        Episode = episode;

        Anime = anime;
        Video = video;
        Media = media;

        _initialOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;

        IsBusy = true;

        _playerSettings.Load();

        SetEpisode(Episode);
    }

    public VideoPlayerViewModel(IAnimeInfo anime, Episode episode, Media media)
        : this(anime, episode, null, media) { }

    public void SetEpisode(Episode episode)
    {
        Episode = episode;

        var index = EpisodeViewModel.Episodes.OrderBy(x => x.Number).ToList().IndexOf(Episode);

        PreviousEpisode = EpisodeViewModel
            .Episodes
            .OrderBy(x => x.Number)
            .ElementAtOrDefault(index - 1);

        NextEpisode = EpisodeViewModel
            .Episodes
            .OrderBy(x => x.Number)
            .ElementAtOrDefault(index + 1);

        EpisodeKey = $"{Media.Id}-{Episode.Number}";
    }

    public bool IsChangingSource { get; set; }

    public async void UpdateSource()
    {
        IsChangingSource = true;
        StartedPlaying = false;

        MediaElement.Stop();

        await Load();
        Controller.UpdateSourceInfo();

        IsChangingSource = false;
    }

    public void PlayPrevious()
    {
        if (PreviousEpisode is null)
            return;

        MediaElement.PositionChanged += MediaElement_PositionChanged;

        Video = null;
        SetEpisode(PreviousEpisode);
        UpdateSource();
    }

    public void PlayNext()
    {
        if (NextEpisode is null)
            return;

        MediaElement.PositionChanged += MediaElement_PositionChanged;

        Video = null;
        SetEpisode(NextEpisode);
        UpdateSource();
    }

    private void MediaElement_PositionChanged(object? sender, MediaPositionChangedEventArgs e)
    {
        MediaElement.PositionChanged -= MediaElement_PositionChanged;

        if (
            MediaElement.Duration.TotalMilliseconds - 8000
            <= MediaElement.Position.TotalMilliseconds
        )
        {
            MediaElement.SeekTo(
                TimeSpan.FromMilliseconds(MediaElement.Position.TotalMilliseconds - 8000)
            );
        }
    }

    public async void MediaEnded()
    {
        await Task.Delay(3500);

        if (CancellationToken.IsCancellationRequested)
            return;

        if (MediaElement.Position.TotalMilliseconds == MediaElement.Duration.TotalMilliseconds)
        {
            PlayNext();
        }
    }

    [RelayCommand]
    public void OnLoaded(IMediaElement mediaElement)
    {
        Shell.Current.Navigating += Current_Navigating;

        MediaElement = mediaElement;
        Controller = new(this);
        Controller.OnLoaded(mediaElement);

        MediaElement.PositionChanged += MediaElement_PositionChanged;
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
        ApplicationEx.SetOrientation(_initialOrientation);
        Controller.Dispose();
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

                if (
                    MediaElement.Duration.TotalMilliseconds > 0
                    && (
                        MediaElement.Position.TotalMilliseconds
                        == MediaElement.Duration.TotalMilliseconds
                    )
                )
                {
                    MediaEnded();
                }
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

        var speedName = await Shell
            .Current
            .DisplayActionSheet("Playback Speed", "", "", speedsName.ToArray());
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
            var video = Video ?? await GetVideoAsync();
            if (video is null)
                return;

            Video = video;

            var source = (UriMediaSource)MediaSource.FromUri(video.VideoUrl)!;
            source.UserAgent =
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36";
            source.Headers = video.Headers;

            Source = source;

#if ANDROID
            if (!IsChangingSource)
            {
                // This runs after source is created and attached to exoplayer
                Controller.Initialize();
            }
#endif

            _playerSettings.WatchedEpisodes.TryGetValue(EpisodeKey, out var watchedEpisode);

            if (watchedEpisode is not null)
            {
                MediaElement.SeekTo(TimeSpan.FromMilliseconds(watchedEpisode.WatchedDuration));
            }
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
        var videoServers = await _provider.GetVideoServersAsync(Episode.Id, CancellationToken);
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
        sheet.BindingContext = new VideoSourceViewModel(sheet, Anime, Episode, Media);

        await sheet.ShowAsync();
    }

    public void UpdateProgress()
    {
        if (IsChangingSource)
            return;

        if (!CanSaveProgress)
            return;

        _playerSettings.WatchedEpisodes.TryGetValue(EpisodeKey, out var watchedEpisode);

        watchedEpisode ??= new();

        watchedEpisode.Id = EpisodeKey;
        watchedEpisode.AnimeName = Anime.Title;
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
