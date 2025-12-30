using System.Collections.Generic;
using Anikin.Services;
using Anikin.Utils;
using Anikin.ViewModels.Components;
using Anikin.ViewModels.Framework;

namespace Anikin.ViewModels;

public partial class DownloadViewModel : CollectionViewModel<DownloadItem>
{
    private readonly SettingsService _settingsService;
    private readonly DownloadHistoryDatabase _database;

    public static List<DownloadViewModelBase> Downloads { get; set; } = [];

    public DownloadViewModel(SettingsService settingsService, DownloadHistoryDatabase database)
    {
        _settingsService = settingsService;
        _database = database;

        _settingsService.Load();
    }

    /*public async void EnqueueDownload(YoutubeDownloadViewModel download)
    {
        await _database.AddItemAsync(DownloadItem.From(download));

        Downloads.Add(download);

        download.BeginDownload();

        _downloadSemaphore.MaxCount = _settingsService.ParallelLimit;

        await Task.Run(async () =>
        {
            try
            {
                //App.StartForeground();
                //await Task.Delay(10000);
                //App.StopForeground();
                //return;

                using var access = await _downloadSemaphore.AcquireAsync(
                    download.CancellationToken
                );

                download.Status = DownloadStatus.Started;

                var downloadOption =
                    download.DownloadOption
                    ?? await _videoDownloader.GetBestDownloadOptionAsync(
                        download.Video!.Id,
                        download.DownloadPreference!,
                        download.CancellationToken
                    );

                var progress = new ProgressReporter();
                progress.OnReport += (_, e) => download.PercentageProgress = e;

                download.IsProgressIndeterminate = false;

                await _videoDownloader.DownloadVideoAsync(
                    download.TempFilePath!,
                    download.Video!,
                    downloadOption,
                    _settingsService.ShouldInjectSubtitles,
                    progress,
                    download.CancellationToken
                );

                download.IsProgressIndeterminate = true;

                if (_settingsService.ShouldInjectTags)
                {
                    try
                    {
                        await _mediaTagInjector.InjectTagsAsync(
                            download.TempFilePath!,
                            download.Video!,
                            download.CancellationToken
                        );
                    }
                    catch
                    {
                        // Media tagging is not critical
                    }
                }

#if ANDROID
                if (Platform.CurrentActivity is not null)
                {
                    await Platform.CurrentActivity.CopyFileAsync(
                        download.TempFilePath!,
                        download.FilePath!,
                        download.CancellationToken
                    );
                }
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

                // Short error message for YouTube-related errors, full for others
                download.ErrorMessage = ex is YoutubeExplodeException ? ex.Message : ex.ToString();

                try
                {
                    // Delete file
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
                    // Delete temporary downloaded file
                    File.Delete(download.TempFilePath!);
                }
                catch
                {
                    // Ignore
                }

                download.EndDownload();
                download.Dispose();

                Downloads.Remove(download);

                if (Downloads.Count == 0)
                {
                    NotificationHelper.ShowCompletedNotification(
                        $"Saved to {Path.GetDirectoryName(download.FilePath)}"
                    );

                    //var test = ApplicationEx.IsRunning();
                    //var test2 = ApplicationEx.IsInBackground();
                    //var test3 = ApplicationEx.IsInForeground();
                    App.StopForeground();
                    //var test4 = ApplicationEx.IsRunning();
                }
            }
        });
    }*/
}
