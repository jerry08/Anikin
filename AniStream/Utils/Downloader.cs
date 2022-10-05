using System;
using System.Linq;
using Android.App;
using Android.Webkit;
using Android.Widget;
using AnimeDl.Models;

namespace AniStream.Utils
{
    public class Downloader
    {
        private Activity Activity;

        public Downloader(Activity activity)
        {
            Activity = activity;
        }

        public async void Download(Episode episode, Video video)
        {
            var androidStoragePermission = new AndroidStoragePermission(Activity);

            bool hasStoragePermission = androidStoragePermission.HasStoragePermission();
            if (!hasStoragePermission)
            {
                hasStoragePermission = await androidStoragePermission.RequestStoragePermission();
            }

            if (!hasStoragePermission)
            {
                return;
            }

            MimeTypeMap mime = MimeTypeMap.Singleton;
            string mimeType = mime.GetMimeTypeFromExtension("mp4");
            string mimeTypem4a = mime.GetMimeTypeFromExtension("m4a");

            //string invalidCharRemoved = Episode.EpisodeName.Replace("[\\\\/:*?\"<>|]", "");

            var invalidChars = System.IO.Path.GetInvalidFileNameChars();

            string invalidCharsRemoved = new string(episode.Name
              .Where(x => !invalidChars.Contains(x))
              .ToArray());

            var request = new DownloadManager.Request(Android.Net.Uri.Parse(video.VideoUrl));

            for (int i = 0; i < video.Headers.Count; i++)
            {
                request.AddRequestHeader(video.Headers.Keys[i], video.Headers[i]);
            }

            request.SetMimeType(mimeType);
            request.AllowScanningByMediaScanner();
            request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
            //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
            //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");

            //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
            request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryDownloads, invalidCharsRemoved + ".mp4");
            var dm = (DownloadManager)Application.Context.GetSystemService(Application.DownloadService);
            long id = dm.Enqueue(request);

            Toast.MakeText(Activity, "Download started", ToastLength.Short).Show();
        }
    }
}