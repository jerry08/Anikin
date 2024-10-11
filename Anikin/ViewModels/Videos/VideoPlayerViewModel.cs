using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Subtitles;
using Anikin.ViewModels.Framework;
using Anikin.Views.BottomSheets;
using Berry.Maui;
using Berry.Maui.Core;
using Berry.Maui.Core.Primitives;
using Berry.Maui.Views;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Httpz.Utils.Extensions;
using Juro.Clients;
using Juro.Core.Models;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Juro.Core.Providers;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;
using Media = Jita.AniList.Models.Media;

namespace Anikin.ViewModels;

public partial class VideoPlayerViewModel : BaseViewModel
{
    private readonly SettingsService _settingsService = new();
    private readonly PlayerSettings _playerSettings = new();
    private readonly DisplayOrientation _initialOrientation;

    private readonly AnimeApiClient _apiClient = new(Constants.ApiEndpoint);

    private bool IsDisposed { get; set; }

    public Media Media { get; private set; }
    public IAnimeInfo Anime { get; private set; }
    public VideoSource? Video { get; set; }
    public List<SubtitleItem> SubtitleItems { get; set; } = [];

    [ObservableProperty]
    string? _currentSubtitle;

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

        _settingsService.Load();

        _apiClient.ProviderKey = _settingsService.LastProviderKey!;

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
            .Episodes.OrderBy(x => x.Number)
            .ElementAtOrDefault(index - 1);

        NextEpisode = EpisodeViewModel
            .Episodes.OrderBy(x => x.Number)
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
        // Windows MediaElement not calling StateChanged when a video starts
        // playing for some reason.
        OnStateChanged(MediaElementState.Playing);

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
        (MediaElement as MediaElement)?.Dispose();
        IsDisposed = true;
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

#if !ANDROID
                IsBusy = false;
                IsRefreshing = false;
                App.AlertService.ShowAlert("Error", "Failed to play video. Try another source.");
#endif
                break;
            default:
                break;
        }
    }

    public async Task ShowSpeedSelector()
    {
        var speeds = _playerSettings.GetSpeeds();
        var speedsName = speeds.Select(speed => $"{speed}x").ToList();

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
            var video = Video ?? await GetVideoAsync();
            if (video is null)
                return;

            var language = CultureInfo.CurrentCulture.IsNeutralCulture
                ? CultureInfo.CurrentCulture.EnglishName
                : CultureInfo.CurrentCulture.Parent.EnglishName;

            var subtitle = video.Subtitles.Find(x =>
                x.Language.Equals(language, StringComparison.OrdinalIgnoreCase)
            );
            if (subtitle is not null)
            {
                var http = new HttpClient();

                var subtitlesStr = await http.ExecuteAsync(
                    subtitle.Url,
                    subtitle.Headers!,
                    CancellationToken
                );

                ISubtitlesParser parser = video.Subtitles[0].Type switch
                {
                    SubtitleType.VTT => new VttParser(),
                    SubtitleType.ASS => throw new NotImplementedException(),
                    SubtitleType.SRT => new SrtParser(),
                    _ => throw new NotImplementedException(),
                };

                var bytes = Encoding.UTF8.GetBytes(subtitlesStr);
                var stream = new MemoryStream(bytes);
                SubtitleItems = parser.ParseStream(stream, Encoding.UTF8);

                StartUpdatingSubtitles();
            }

            Video = video;

            var source = (UriMediaSource)MediaSource.FromUri(video.VideoUrl)!;
            source.UserAgent =
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36";
            source.Headers = video.Headers;

            Source = source;

            if (!IsChangingSource)
            {
                // This runs after source is created and attached to exoplayer
                Controller.Initialize();
            }

            _playerSettings.WatchedEpisodes.TryGetValue(EpisodeKey, out var watchedEpisode);

            if (watchedEpisode is not null)
            {
                await MediaElement.SeekTo(
                    TimeSpan.FromMilliseconds(watchedEpisode.WatchedDuration)
                );
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

        var videos = await _apiClient.GetVideosAsync(videoServer.Embed.Url, CancellationToken);
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
        var videoServers = await _apiClient.GetVideoServersAsync(Episode.Id, CancellationToken);
        if (videoServers.Count == 0)
            return null;

        return videoServers.Find(x =>
                x.Name?.Contains("streamsb", StringComparison.OrdinalIgnoreCase) == true
                || x.Name?.Contains("vidstream", StringComparison.OrdinalIgnoreCase) == true
                || x.Name?.Equals("mirror", StringComparison.OrdinalIgnoreCase) == true // Indonesian
            ) ?? videoServers[0];
    }

    private void StartUpdatingSubtitles()
    {
        Task.Run(async () =>
        {
            while (SubtitleItems.Count > 0 && !CancellationToken.IsCancellationRequested)
            {
                var currentSubtitle = SubtitleItems.FirstOrDefault(x =>
                    MediaElement.Position.TotalMilliseconds >= x.StartTime
                    && MediaElement.Position.TotalMilliseconds <= x.EndTime
                );

                if (currentSubtitle is not null)
                {
                    CurrentSubtitle = string.Join(Environment.NewLine, currentSubtitle.Lines);
                }

                await Task.Delay(50);
            }
        });
    }

    async Task ShowSheet()
    {
        var sheet = new VideoSourceSheet();
        sheet.BindingContext = new VideoSourceViewModel(sheet, Anime, Episode, Media);

        await sheet.ShowAsync();
    }

    public void UpdateProgress()
    {
        if (IsChangingSource || !CanSaveProgress || IsDisposed)
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
