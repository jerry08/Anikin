using System;
using System.Collections.Specialized;
using System.Linq;
using Android.App;
using Android.Webkit;
using Android.Widget;

namespace AniStream.Utils
{
    public class Downloader
    {
        private readonly Activity _activity;

        public Downloader(Activity activity)
        {
            _activity = activity;
        }

        public async void Download(string fileName, string url, NameValueCollection? headers = null)
        {
            var androidStoragePermission = new AndroidStoragePermission(_activity);

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
            var mimeType = mime.GetMimeTypeFromExtension("mp4");
            var mimeTypem4a = mime.GetMimeTypeFromExtension("m4a");

            //string invalidCharRemoved = Episode.EpisodeName.Replace("[\\\\/:*?\"<>|]", "");

            var invalidChars = System.IO.Path.GetInvalidFileNameChars();

            var invalidCharsRemoved = new string(fileName
              .Where(x => !invalidChars.Contains(x))
              .ToArray());

            var request = new DownloadManager.Request(Android.Net.Uri.Parse(url));

            if (headers is not null)
            {
                for (int i = 0; i < headers.Count; i++)
                    request.AddRequestHeader(headers.Keys[i], headers[i]);
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

            Toast.MakeText(_activity, "Download started", ToastLength.Short).Show();
        }
    }
}