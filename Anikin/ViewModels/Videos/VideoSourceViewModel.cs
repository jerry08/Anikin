using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Components;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.BottomSheets;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.Input;
using Gress;
using Httpz;
using Httpz.Hls;
using Juro.Clients;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Storage;
using TaskExecutor;
using Media = Jita.AniList.Models.Media;

namespace Anikin.ViewModels;

public partial class VideoSourceViewModel : CollectionViewModel<ListGroup<VideoSource>>
{
    private readonly SettingsService _settingsService = new();
    private readonly DownloadHistoryDatabase _database = new();
    private readonly AnimeApiClient _apiClient = new(Constants.ApiEndpoint);

    private readonly ResizableSemaphore _downloadSemaphore = new();

    private readonly Media _media;

    private readonly IAnimeInfo _anime;
    private readonly Episode _episode;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private VideoSourceSheet VideoSourceSheet { get; set; }

    public VideoSourceViewModel(
        VideoSourceSheet episodeSelectionSheet,
        IAnimeInfo anime,
        Episode episode,
        Media media
    )
    {
        _anime = anime;
        _episode = episode;
        _media = media;

        VideoSourceSheet = episodeSelectionSheet;

        _settingsService.Load();

        _apiClient.ProviderKey = _settingsService.LastAnimeProviderKey!;

        Load();
    }

    protected override async Task LoadCore()
    {
        IsBusy = true;
        IsLoading = true;

        try
        {
            var videos = await _apiClient.GetVideosAsync(_episode.Id, CancellationToken);
            //Push(videos);

            foreach (var video in videos)
            {
                video.Title ??=
                    !string.IsNullOrEmpty(video.Title) ? video.Title
                    : !string.IsNullOrEmpty(video.Resolution) ? video.Resolution
                    : "Default Quality";
            }

            var groups = videos.GroupBy(x => x.VideoServer?.Name);

            foreach (var group in groups)
            {
                Entities.Add(new(group.Key ?? "Default Server", [.. group]));
            }
        }
        catch (Exception ex)
        {
            if (App.IsInDeveloperMode)
            {
                await MainThread.InvokeOnMainThreadAsync(async () =>
                {
                    await App.AlertService.ShowAlertAsync("Error", $"{ex}");
                });
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
            IsLoading = false;

            OnPropertyChanged(nameof(Entities));
        }
    }

    [RelayCommand]
    private async Task ItemClick(VideoSource video)
    {
        await VideoSourceSheet.DismissAsync();

        if (Shell.Current.CurrentPage?.BindingContext is VideoPlayerViewModel videoPlayerViewModel)
        {
            videoPlayerViewModel.Video = video;
            videoPlayerViewModel.UpdateSource();
            return;
        }

        var page = new VideoPlayerView
        {
            BindingContext = new VideoPlayerViewModel(_anime, _episode, video, _media),
        };

        await Shell.Current.Navigation.PushAsync(page);
    }

    [RelayCommand]
    private async Task ItemLongClick(VideoSource video)
    {
        var url = video.VideoUrl.Replace(" ", "%20");

        await Clipboard.Default.SetTextAsync(url);

        await Toast
            .Make($"Copied to clipboard:{Environment.NewLine}{url}", ToastDuration.Short, 16)
            .Show();

#if ANDROID
        var videoUri = Android.Net.Uri.Parse(url);

        var intent = new Android.Content.Intent(Android.Content.Intent.ActionView);
        intent.SetDataAndType(videoUri, "video/*");
        intent.SetFlags(Android.Content.ActivityFlags.NewTask);

        //_activity.CopyToClipboard(url, false);
        //_activity.ShowToast($"Copied \"{url}\"");

        var chooserIntent = Android.Content.Intent.CreateChooser(intent, "Open Video in :")!;
        chooserIntent.SetFlags(Android.Content.ActivityFlags.NewTask);

        Platform.CurrentActivity?.StartActivity(chooserIntent);
#endif
    }

    [RelayCommand]
    async Task Download(VideoSource video)
    {
        var hlsDownloader = new HlsDownloader();
        var isHls = hlsDownloader.Supports(new Uri(video.VideoUrl));

        HlsStreamMetadata? selectedQuality = null;

        if (isHls)
        {
            try
            {
                var qualities = await hlsDownloader.GetQualitiesAsync(
                    video.VideoUrl,
                    video.Headers,
                    CancellationToken
                );

                if (qualities.Count == 0)
                {
                    await Toast.Make("No qualities found").Show();
                    return;
                }

                var qualityLabels = qualities
                    .Select(q =>
                        q.Resolution is not null
                            ? $"{q.Resolution.Height}p ({q.Resolution})"
                            : q.Name ?? $"{q.Bandwidth / 1000}kbps"
                    )
                    .ToArray();

                var selected = await Shell.Current.DisplayActionSheetAsync(
                    "Select Quality",
                    "Cancel",
                    null,
                    qualityLabels
                );

                if (selected is null or "Cancel")
                    return;

                var selectedIndex = Array.IndexOf(qualityLabels, selected);
                selectedQuality = qualities[selectedIndex];
            }
            catch (Exception ex)
            {
                if (App.IsInDeveloperMode)
                    await App.AlertService.ShowAlertAsync("Error", $"{ex}");

                await Toast.Make("Failed to fetch qualities").Show();
                return;
            }
        }

        var title = $"{_anime.Title} - Ep {_episode.Number}";

        var invalidChars = Path.GetInvalidFileNameChars();
        var safeTitle = new string(title.Where(c => !invalidChars.Contains(c)).ToArray());

        var ext = isHls
            ? $".{selectedQuality!.OutputFormat.Extension}"
            : Path.GetExtension(new Uri(video.VideoUrl).AbsolutePath);
        if (string.IsNullOrEmpty(ext) || ext.Length > 5)
            ext = ".mp4";

        var fileName = $"{safeTitle}{ext}";

        var download = new VideoDownloadViewModel() { Anime = _anime };

        download.TempFilePath = Path.Combine(FileSystem.AppDataDirectory, fileName);
        download.FilePath = Path.Combine(
#if ANDROID
            Android
                .OS.Environment.GetExternalStoragePublicDirectory(
                    Android.OS.Environment.DirectoryDownloads
                )
                ?.AbsolutePath
                ?? FileSystem.AppDataDirectory,
#else
            Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
#endif
            fileName
        );

        await _database.AddItemAsync(DownloadItem.From(video, title));

        DownloadViewModel.Downloads.Add(download);

        download.BeginDownload();

        _downloadSemaphore.MaxCount = _settingsService.ParallelLimit;

#if ANDROID
        NotificationHelper.StartForeground();
#endif

        _ = Task.Run(async () =>
        {
            try
            {
                using var access = await _downloadSemaphore.AcquireAsync(
                    download.CancellationToken
                );

                download.Status = DownloadStatus.Started;

                var progress = new Progress<double>(p =>
                    download.PercentageProgress = Percentage.FromFraction(p)
                );

                download.IsProgressIndeterminate = false;

                if (isHls && selectedQuality?.Stream is not null)
                {
                    await hlsDownloader.DownloadAllThenMergeAsync(
                        selectedQuality.Stream,
                        video.Headers ?? new Dictionary<string, string?>(),
                        download.TempFilePath,
                        progress: progress,
                        cancellationToken: download.CancellationToken
                    );
                }
                else
                {
                    var downloader = new Downloader();
                    await downloader.DownloadAsync(
                        video.VideoUrl,
                        download.TempFilePath,
                        video.Headers,
                        progress: progress,
                        cancellationToken: download.CancellationToken
                    );
                }

#if ANDROID
                if (Platform.CurrentActivity is not null)
                {
                    await Platform.CurrentActivity.CopyFileAsync(
                        download.TempFilePath,
                        download.FilePath!,
                        download.CancellationToken
                    );
                }
#else
                File.Copy(download.TempFilePath, download.FilePath!, true);
#endif

                download.Status = DownloadStatus.Completed;
            }
            catch (Exception ex)
            {
                download.PercentageProgress = Percentage.FromValue(100);

                download.Status =
                    ex is OperationCanceledException
                        ? DownloadStatus.Canceled
                        : DownloadStatus.Failed;

                download.ErrorMessage = ex.Message;

                try
                {
                    if (!string.IsNullOrEmpty(download.FilePath))
                        File.Delete(download.FilePath);
                }
                catch
                {
                    // Ignore
                }
            }
            finally
            {
                try
                {
                    File.Delete(download.TempFilePath);
                }
                catch
                {
                    // Ignore
                }

                download.EndDownload();
                download.Dispose();

                DownloadViewModel.Downloads.Remove(download);

                if (DownloadViewModel.Downloads.Count == 0)
                {
#if ANDROID
                    NotificationHelper.ShowCompletedNotification(
                        $"Saved to {Path.GetDirectoryName(download.FilePath)}"
                    );
                    NotificationHelper.StopForeground();
#endif
                }
            }
        });

        await Toast.Make($"Downloading {title}").Show();
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
