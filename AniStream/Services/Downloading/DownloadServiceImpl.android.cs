using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.Webkit;
using AniStream.Utils;
using AniStream.Utils.Downloading;
using CommunityToolkit.Maui.Alerts;
using Microsoft.Maui.ApplicationModel;

namespace AniStream.Services;

public class DownloadServiceImpl : IDownloadService
{
    public async Task EnqueueAsync(
        string fileName,
        string url,
        IDictionary<string, string>? headers = null
    )
    {
        var androidStoragePermission = new AndroidStoragePermission();

        if (Platform.CurrentActivity is MainActivity activity)
            activity.AndroidStoragePermission = androidStoragePermission;

        var hasStoragePermission = androidStoragePermission.HasStoragePermission();
        if (!hasStoragePermission)
        {
            hasStoragePermission = await androidStoragePermission.RequestStoragePermission();
        }

        if (!hasStoragePermission)
            return;

        var status = await StoragePermissionUtil.CheckAndRequestStoragePermission();
        if (status == PermissionStatus.Denied)
        {
            await Snackbar.Make("Storage permission not granted.").Show();
            return;
        }

        var extension = System.IO.Path.GetExtension(fileName).Split('.').LastOrDefault();
        if (extension == "apk")
        {
            var intentFilter = new IntentFilter();
            intentFilter.AddAction(DownloadManager.ActionDownloadComplete);

            Platform.CurrentActivity?.RegisterReceiver(new ApkDownloadReceiver(), intentFilter);
        }

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension(extension);

        var invalidChars = System.IO.Path.GetInvalidFileNameChars();

        var invalidCharsRemoved = new string(
            fileName.Where(x => !invalidChars.Contains(x)).ToArray()
        );

        var request = new DownloadManager.Request(Android.Net.Uri.Parse(url));

        for (var i = 0; i < headers?.Count; i++)
            request.AddRequestHeader(headers.ElementAt(i).Key, headers.ElementAt(i).Value);

        request.SetMimeType(mimeType);
        request.AllowScanningByMediaScanner();
        request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
        //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
        //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");

        //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
        request.SetDestinationInExternalPublicDir(
            Android.OS.Environment.DirectoryDownloads,
            invalidCharsRemoved
        );
        var dm = (DownloadManager)
            Application.Context.GetSystemService(Android.Content.Context.DownloadService)!;
        var id = dm.Enqueue(request);
    }
}
