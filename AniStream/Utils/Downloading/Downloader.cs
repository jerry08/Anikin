using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.Webkit;
using AniStream.Services;
using AniStream.Utils.Extensions;
using AniStream.Utils.Listeners;
using JGrabber.Grabbed;
using Newtonsoft.Json;

namespace AniStream.Utils.Downloading;

public class Downloader
{
    private readonly Activity _activity;

    public Downloader(Activity activity)
    {
        _activity = activity;
    }

    public async void Download(
        string fileName,
        string url,
        Dictionary<string, string>? headers = null)
    {
        var androidStoragePermission = new AndroidStoragePermission(_activity);

        if (_activity is ActivityBase activity)
            activity.AndroidStoragePermission = androidStoragePermission;

        var hasStoragePermission = androidStoragePermission.HasStoragePermission();
        if (!hasStoragePermission)
        {
            //_activity.ShowToast("Please grant storage permission then retry");
            hasStoragePermission = await androidStoragePermission.RequestStoragePermission();
        }

        if (!hasStoragePermission)
            return;

        var extension = System.IO.Path.GetExtension(fileName).Split('.').LastOrDefault();

        if (extension == "apk")
        {
            var intentFilter = new IntentFilter();
            intentFilter.AddAction(DownloadManager.ActionDownloadComplete);

            _activity.RegisterReceiver(new ApkDownloadReceiver(), intentFilter);
        }

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension(extension);

        var invalidChars = System.IO.Path.GetInvalidFileNameChars();

        var invalidCharsRemoved = new string(fileName
          .Where(x => !invalidChars.Contains(x)).ToArray());

        var request = new DownloadManager.Request(Android.Net.Uri.Parse(url));

        for (var i = 0; i < headers?.Count; i++)
            request.AddRequestHeader(headers.ElementAt(i).Key, headers.ElementAt(i).Value);

        request.SetMimeType(mimeType);
        request.AllowScanningByMediaScanner();
        request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
        //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
        //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");

        //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
        request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryDownloads, invalidCharsRemoved);

        var downloadManager = (DownloadManager)Application.Context.GetSystemService(
            Android.Content.Context.DownloadService
        )!;

        var id = downloadManager.Enqueue(request);

        _activity.ShowToast("Download started");
    }

    /*public async Task DownloadHls(
        string fileName,
        string url,
        Dictionary<string, string> headers)
    {
        if (!_activity.IsPackageInstalled("com.oneb.anistreamffmpeg"))
        {
            var builder = new AlertDialog.Builder(_activity, Resource.Style.DialogTheme);
            builder.SetMessage("AniStream.FFmpeg extension is required to convert this video to mp4.");
            builder.SetPositiveButton("Download", async (s, e) =>
            {
                var loadingDialog = WeebUtils.SetProgressDialog(_activity, "Loading...", false);

                var github = new Octokit.GitHubClient(
                    new Octokit.ProductHeaderValue("AniStream.FFmpeg-Download")
                );

                var releaseClient = github.Repository.Release;
                var releases = await releaseClient.GetAll("jerry08", "AniStream.FFmpeg");
                var latestRelease = releases.FirstOrDefault()!;
                var asset = latestRelease.Assets.FirstOrDefault()!;

                loadingDialog.Dismiss();

                Download(asset.Name, asset.BrowserDownloadUrl);
            });

            builder.SetNegativeButton("Cancel", (s, e) => { });

            builder.SetCancelable(true);
            var dialog = builder.Create()!;
            dialog.Show();
        }
        else
        {
            var loadingDialog = WeebUtils.SetProgressDialog(_activity, "Getting qualities. Please wait...", false);
            var metadataResources = new List<GrabbedHlsStreamMetadata>();
            try
            {
                var downloader = new Httpz.HlsDownloader(Http.ClientProvider);

                metadataResources = await downloader.GetHlsStreamMetadatasAsync(url, headers);
                loadingDialog.Dismiss();
            }
            catch
            {
                loadingDialog.Dismiss();
                _activity.ShowToast("Failed to get qualities. Try another source");
                return;
            }

            var listener = new DialogClickListener();
            listener.OnItemClick += async (s, which) =>
            {
                loadingDialog = WeebUtils.SetProgressDialog(_activity, "Loading...", false);
                var stream = await metadataResources[which].Stream;
                loadingDialog.Dismiss();

                //var intent = new Intent();
                //intent.SetComponent(new ComponentName("com.oneb.anistreamffmpeg", "com.oneb.anistreamffmpeg.DownloadService"));
                var intent = new Intent(_activity, typeof(DownloadService));
                intent.PutExtra("stream", JsonConvert.SerializeObject(stream));
                intent.PutExtra("headers", JsonConvert.SerializeObject(headers));
                intent.PutExtra("fileName", fileName);

                _activity.StartForegroundService(intent);
            };

            var builder = new AlertDialog.Builder(_activity, Resource.Style.DialogTheme);
            builder.SetTitle(fileName);
            builder.SetNegativeButton("Cancel", (s, e) => { });

            var items = metadataResources.Select(x => x.Resolution?.ToString()
                ?? "Default quality").ToArray();

            builder.SetItems(items, listener);
            builder.SetCancelable(true);
            var dialog = builder.Create()!;
            dialog.SetCanceledOnTouchOutside(false);
            dialog.Show();
        }
    }*/

    public async Task DownloadHls(
        string fileName,
        string url,
        Dictionary<string, string> headers)
    {
        var loadingDialog = WeebUtils.SetProgressDialog(
            _activity,
            "Getting qualities. Please wait...",
            true
        );

        var cancellationTokenSource = new CancellationTokenSource();

        loadingDialog.CancelEvent += delegate
        {
            cancellationTokenSource.Cancel();
        };

        var metadataResources = new List<GrabbedHlsStreamMetadata>();

        try
        {
            var downloader = new Httpz.HlsDownloader(Http.ClientProvider);

            metadataResources = await downloader.GetHlsStreamMetadatasAsync(
                url,
                headers,
                cancellationTokenSource.Token
            );

            loadingDialog.Dismiss();
        }
        catch
        {
            loadingDialog.Dismiss();

            if (!cancellationTokenSource.IsCancellationRequested)
                _activity.ShowToast("Failed to get qualities. Try another source");

            return;
        }

        var listener = new DialogClickListener();
        listener.OnItemClick += async (s, which) =>
        {
            loadingDialog = WeebUtils.SetProgressDialog(_activity, "Loading...", false);
            var stream = await metadataResources[which].Stream;
            loadingDialog.Dismiss();

            //var intent = new Intent();
            //intent.SetComponent(new ComponentName("com.oneb.anistreamffmpeg", "com.oneb.anistreamffmpeg.DownloadService"));
            var intent = new Intent(_activity, typeof(DownloadService));
            intent.PutExtra("stream", JsonConvert.SerializeObject(stream));
            intent.PutExtra("headers", JsonConvert.SerializeObject(headers));
            intent.PutExtra("fileName", fileName);

            _activity.StartForegroundService(intent);
        };

        var builder = new AlertDialog.Builder(_activity, Resource.Style.DialogTheme);
        builder.SetTitle(fileName);
        builder.SetNegativeButton("Cancel", (s, e) => { });

        var items = metadataResources.Select(x => x.Resolution?.ToString()
            ?? "Default quality").ToArray();

        builder.SetItems(items, listener);
        builder.SetCancelable(true);
        var dialog = builder.Create()!;
        dialog.SetCanceledOnTouchOutside(true);
        dialog.Show();
    }
}