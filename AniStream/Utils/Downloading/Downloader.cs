using System;
using System.Linq;
using System.Collections.Specialized;
using Android.App;
using Android.Webkit;
using Android.Widget;
using AniStream.Utils.Extensions;
using Xamarin.Essentials;
using System.Threading.Tasks;
using AnimeDl;
using Laerdal.FFmpeg.Android;
using Plugin.LocalNotification;
using AnimeDl.Models;
using AnimeDl.Scrapers.Interfaces;
using DotNetTools.JGrabber.Grabbed;
using System.Collections.Generic;
using Java.Nio.FileNio.Attributes;

namespace AniStream.Utils.Downloading;

public class Downloader
{
    private readonly Activity _activity;
    private readonly AnimeClient _client = new(WeebUtils.AnimeSite);
    private readonly int _notificationId;

    public Downloader(Activity activity)
    {
        _activity = activity;
        _notificationId = (int)DateTime.Now.Ticks;
    }

    public async void Download(
        string fileName,
        string url,
        NameValueCollection? headers = null)
    {
        var androidStoragePermission = new AndroidStoragePermission(_activity);

        bool hasStoragePermission = androidStoragePermission.HasStoragePermission();
        if (!hasStoragePermission)
        {
            _activity.ShowToast("Please grant storage permission then retry");
            hasStoragePermission = await androidStoragePermission.RequestStoragePermission();
        }

        if (!hasStoragePermission)
            return;

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension("mp4");
        var mimeTypem4a = mime.GetMimeTypeFromExtension("m4a");

        //string invalidCharRemoved = Episode.EpisodeName.Replace("[\\\\/:*?\"<>|]", "");

        var invalidChars = System.IO.Path.GetInvalidFileNameChars();

        var invalidCharsRemoved = new string(fileName
          .Where(x => !invalidChars.Contains(x)).ToArray());

        var request = new DownloadManager.Request(Android.Net.Uri.Parse(url));

        for (int i = 0; i < headers?.Count; i++)
            request.AddRequestHeader(headers.Keys[i], headers[i]);

        request.SetMimeType(mimeType);
        request.AllowScanningByMediaScanner();
        request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
        //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
        //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");

        //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
        request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryDownloads, invalidCharsRemoved);
        var dm = (DownloadManager)Application.Context.GetSystemService(Android.Content.Context.DownloadService);
        long id = dm.Enqueue(request);

        _activity.ShowToast("Download started");
    }

    public async Task DownloadHls(
        string fileName,
        string url,
        NameValueCollection headers)
    {
        var loadingDialog = WeebUtils.SetProgressDialog(_activity, "Getting qualities. Please wait...", false);

        var metadataResources = await _client.GetHlsStreamMetadatasAsync(url, headers);

        loadingDialog.Dismiss();

        var listener = new DialogClickListener();
        listener.OnItemClick += async (s, which) =>
        {
            await DownloadHls(fileName, metadataResources[which], headers);
        };

        var builder = new AlertDialog.Builder(_activity);
        builder.SetTitle(fileName);

        builder.SetNegativeButton("Cancel", (sender2, ev2) =>
        {
        });

        var items = metadataResources.Select(x => x.Resolution.ToString()).ToArray();
        builder.SetItems(items, listener);
        builder.SetCancelable(true);
        var dialog = builder.Create()!;
        dialog.SetCanceledOnTouchOutside(false);
        dialog.Show();
    }

    public async Task DownloadHls(
        string fileName,
        GrabbedHlsStreamMetadata metadataResource,
        NameValueCollection headers)
    {
        var cacheDir = FileSystem.CacheDirectory;

        var fileNameWithoutExtension = System.IO.Path.GetFileNameWithoutExtension(fileName);

        var filePath = System.IO.Path.Combine(cacheDir, $"{fileNameWithoutExtension}.ts");
        var newFilePath = System.IO.Path.Combine(cacheDir, fileName);
        var saveFilePath = System.IO.Path.Combine(Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads).AbsolutePath, $"{fileNameWithoutExtension}.mp4");

        _activity.RunOnUiThread(() =>
        {
            Toast.MakeText(_activity, "Started", ToastLength.Short)!.Show();
        });

        using (var progress = new DownloaderProgress(_notificationId, fileName))
            await _client.DownloadTsAsync(metadataResource, headers, filePath, progress);

        ShowProcessingNotification(fileName);

        var cmd = $@"-i ""{filePath}"" -acodec copy -vcodec copy ""{newFilePath}""";
        var returnCode = FFmpeg.Execute(cmd);
        if (returnCode == Config.ReturnCodeSuccess)
        {
            await _activity.CopyFileUsingMediaStore(newFilePath, saveFilePath);
            ShowCompletedNotification(fileName, "Completed");
        }
        else
        {
            ShowCompletedNotification(fileName, "Failed to convert video");
        }

        System.IO.File.Delete(filePath);
        System.IO.File.Delete(newFilePath);
    }

    private void ShowProcessingNotification(string title)
    {
        var notification = new NotificationRequest
        {
            Silent = true,
            NotificationId = _notificationId,
            Title = title,
            Description = "Converting video",
            Android =
            {
                IconSmallName =
                {
                    ResourceName = "logo_transparent_bg",
                },
                Color =
                {
                    ResourceName = "colorPrimary"
                },
                IsProgressBarIndeterminate = true,
                ProgressBarMax = 100,
                ProgressBarProgress = 100,
                Ongoing = true
            }
        };

        LocalNotificationCenter.Current.Show(notification);
    }

    private void ShowCompletedNotification(string title, string message)
    {
        var notification = new NotificationRequest
        {
            Silent = true,
            NotificationId = _notificationId,
            Title = title,
            Description = message,
            Android =
            {
                IconSmallName =
                {
                    ResourceName = "logo_transparent_bg",
                },
                Color =
                {
                    ResourceName = "colorPrimary"
                }
            }
        };

        LocalNotificationCenter.Current.Show(notification);
    }
}