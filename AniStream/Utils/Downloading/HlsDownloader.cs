using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.Webkit;
using AndroidX.Core.App;
using AndroidX.Core.Content;
using AniStream.Services;
using AniStream.Utils.Extensions;
using JGrabber.Grabbed;
using Laerdal.FFmpeg.Android;
using Microsoft.Maui.Storage;

namespace AniStream.Utils.Downloading;

public class HlsDownloader
{
    private readonly Service _service;
    private readonly int _notificationId;

    public HlsDownloader(Service service)
    {
        _service = service;
        _notificationId = (int)DateTime.Now.Ticks;
    }

    public async Task DownloadAsync(
        string fileName,
        GrabbedHlsStream stream,
        Dictionary<string, string> headers,
        CancellationToken cancellationToken = default)
    {
        var cacheDir = FileSystem.CacheDirectory;

        var fileNameWithoutExtension = System.IO.Path.GetFileNameWithoutExtension(fileName);

        var filePath = System.IO.Path.Combine(cacheDir, $"{fileNameWithoutExtension}.ts");
        var newFilePath = System.IO.Path.Combine(cacheDir, fileName);
        var saveFilePath = System.IO.Path.Combine(Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads)!.AbsolutePath, $"{fileNameWithoutExtension}.mp4");

        if (System.IO.File.Exists(filePath))
            System.IO.File.Delete(filePath);

        using (var progress = new DownloaderProgress(_service, _notificationId, fileName))
        {
            try
            {
                var downloader = new Httpz.HlsDownloader(Http.ClientProvider);

                //await downloader.DownloadAsync(stream, headers, filePath, progress, cancellationToken);
                await downloader.DownloadAllThenMergeAsync(stream, headers, filePath, progress, 15, cancellationToken);
            }
            catch
            {
                //Cancelled from cancellationToken

                if (System.IO.File.Exists(filePath))
                    System.IO.File.Delete(filePath);

                return;
            }
        }

        ShowProcessingNotification(fileName);

        if (System.IO.File.Exists(newFilePath))
            System.IO.File.Delete(newFilePath);

        if (cancellationToken.IsCancellationRequested)
        {
            if (System.IO.File.Exists(filePath))
                System.IO.File.Delete(filePath);

            return;
        }

        var flags = PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable;

        //This allows ffmpeg to return result and continue operations in app
        Config.IgnoreSignal(Signal.Sigxcpu);

        var cmd = $@"-i ""{filePath}"" -acodec copy -vcodec copy ""{newFilePath}""";
        var returnCode = FFmpeg.Execute(cmd);
        if (returnCode == Config.ReturnCodeSuccess)
        //if (true)
        {
            await _service.CopyFileAsync(newFilePath, saveFilePath, cancellationToken);

            var ext = System.IO.Path.GetExtension(saveFilePath).Replace(".", "");
            var type = MimeTypeMap.Singleton!.GetMimeTypeFromExtension(ext)!;

            //var uri = Android.Net.Uri.FromFile(new Java.IO.File(saveFilePath));
            //var uri = FileProvider.GetUriForFile(_service,
            //    _service.PackageName + ".provider", new Java.IO.File(saveFilePath));
            var uri = Android.Net.Uri.Parse(saveFilePath);

            var intent = new Intent(Intent.ActionView);
            intent.SetFlags(ActivityFlags.ClearTop);
            intent.SetDataAndType(uri, type);

            var pendingIntent = PendingIntent.GetActivity(_service, 0, intent, flags)!;

            if (!cancellationToken.IsCancellationRequested)
                ShowCompletedNotification(fileName, "Completed", pendingIntent);
        }
        else
        {
            var intent = new Intent();
            var pendingIntent = PendingIntent.GetActivity(_service, 0, intent, flags)!;

            if (!cancellationToken.IsCancellationRequested)
                ShowCompletedNotification(fileName, "Failed to convert video", pendingIntent);
        }

        if (System.IO.File.Exists(filePath))
            System.IO.File.Delete(filePath);

        if (System.IO.File.Exists(newFilePath))
            System.IO.File.Delete(newFilePath);

        if (cancellationToken.IsCancellationRequested && System.IO.File.Exists(saveFilePath))
            System.IO.File.Delete(saveFilePath);
    }

    private void ShowProcessingNotification(string title)
    {
        if (!_service.HasNotificationPermission())
            return;

        var flags = PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable;

        var intent = new Intent();
        var pendingIntent = PendingIntent.GetActivity(_service, 0, intent, flags);

        var cancelIntent = new Intent(_service, typeof(DownloadService));
        cancelIntent.SetAction("cancel_download");
        var cancelPendingIntent = PendingIntent.GetForegroundService(_service, 3462, cancelIntent, flags);

        var channelId = $"{_service.PackageName}.general";

        var color = ContextCompat.GetColor(_service, Resource.Color.colorPrimary);

        var builder = new NotificationCompat.Builder(_service, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(true)
            .SetContentTitle(title)
            .SetContentText("Converting video")
            .SetContentIntent(pendingIntent)
            .SetProgress(100, 100, true)
            .SetColor(color)
            .AddAction(Resource.Drawable.logo_notification, "Cancel", cancelPendingIntent)
            .SetPriority(NotificationCompat.PriorityLow);

        _service.StartForeground(_notificationId, builder.Build());
    }

    private void ShowCompletedNotification(string title, string message, PendingIntent pendingIntent)
    {
        if (!_service.HasNotificationPermission())
            return;

        var channelId = $"{_service.PackageName}.general";

        var color = ContextCompat.GetColor(_service, Resource.Color.colorPrimary);

        var builder = new NotificationCompat.Builder(_service, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(false)
            .SetContentTitle(title)
            .SetContentText(message)
            .SetContentIntent(pendingIntent)
            .SetColor(color)
            .SetPriority(NotificationCompat.PriorityLow);

        var notificationId = (int)DateTime.Now.Ticks;

        var notificationManager = NotificationManagerCompat.From(_service);
        //var notificationManager = (NotificationManager)GetSystemService(NotificationService);
        notificationManager.Notify(notificationId, builder.Build());

        _service.StopSelf();
    }
}