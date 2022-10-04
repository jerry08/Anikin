using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Webkit;
using Android.Widget;
using AndroidX.AppCompat.App;
using AndroidX.Core.App;
using AndroidX.Core.Content;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using AnimeDl;

namespace AniStream.Utils
{
    public class Downloader : Java.Lang.Object, IDialogInterfaceOnClickListener
    {
        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);
        private EpisodesActivity Activity;
        private Episode Episode;

        public Downloader(EpisodesActivity activity, Anime anime, Episode episode)
        {
            Activity = activity;
            Episode = episode;

            Activity.OnPermissionsResult += Activity_OnPermissionsResult;
        }

        private void Activity_OnPermissionsResult(object sender, EventArgs e)
        {
            var ggs = new AndroidStoragePermission(Activity);
            ggs.HasStoragePermission();

            var gg = ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.WriteExternalStorage);
            
            var g2g = ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.ReadExternalStorage);

            if (ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.WriteExternalStorage) != Permission.Granted
               || ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.ReadExternalStorage) != Permission.Granted)
            {
                Toast.MakeText(Activity, "Failed to Download video", ToastLength.Short).Show();

                return;
            }
            else
            {
                Activity.OnPermissionsResult -= Activity_OnPermissionsResult;

                // Permission has already been granted

                Download();
            }
        }

        public async void Download()
        {
            var test = new AndroidStoragePermission(Activity);
            if (!test.HasStoragePermission())
            {
                var gg = await test.RequestStoragePermission();
            }

            /*if (ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.WriteExternalStorage)
               != Permission.Granted || ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.ReadExternalStorage)
               != Permission.Granted)
            {
                ActivityCompat.RequestPermissions(Activity,
                    new string[]
                    {
                        Manifest.Permission.ReadExternalStorage,
                        Manifest.Permission.WriteExternalStorage
                    }, 1);

                return;
            }
            else
            {
                // Permission has already been granted
            }*/

            var loadingDialog = WeebUtils.SetProgressDialog(Activity, "Getting Download Links...", false);

            _client.OnVideoServersLoaded += (s, e) =>
            {
                loadingDialog.Dismiss();

                var servers = e.VideoServers.Select(x => x.Name).ToArray();

                var builder = new Android.App.AlertDialog.Builder(Activity,
                    Android.App.AlertDialog.ThemeDeviceDefaultLight);
                builder.SetTitle("Select Server");
                builder.SetItems(servers, (s2, e2) =>
                {
                    _client.OnVideosLoaded += (s3, e3) =>
                    {
                        var alert = new AlertDialog.Builder(Activity);

                        var videos = _client.Videos.Where(x => !x.IsM3U8).ToList();
                        if (videos.Count <= 0)
                        {
                            alert.SetMessage("No downloads are available because this source does not allow downloading. Please try a different source.");
                            alert.SetPositiveButton("OK", (s, e) =>
                            {
                            });
                        }
                        else
                        {
                            alert.SetTitle("Download - " + Episode.Name);

                            alert.SetNegativeButton("Cancel", (sender2, ev2) =>
                            {

                            });

                            var items = videos.Select(x => x.Resolution).ToArray();

                            alert.SetItems(items, this);
                            alert.SetCancelable(true);
                        }

                        //Dialog dialog = builder.Create();
                        var dialog = alert.Create();
                        dialog.SetCanceledOnTouchOutside(false);
                        dialog.Show();
                    };

                    _client.GetVideos(_client.VideoServers[e2.Which]);
                });
                builder.Show();
            };

            _client.GetVideoServers(Episode);
        }

        public void OnClick(IDialogInterface dialog, int which)
        {
            MimeTypeMap mime = MimeTypeMap.Singleton;
            string mimeType = mime.GetMimeTypeFromExtension("mp4");
            string mimeTypem4a = mime.GetMimeTypeFromExtension("m4a");

            var video = _client.Videos[which];

            //string invalidCharRemoved = Episode.EpisodeName.Replace("[\\\\/:*?\"<>|]", "");

            var invalidChars = System.IO.Path.GetInvalidFileNameChars();

            string invalidCharsRemoved = new string(Episode.Name
              .Where(x => !invalidChars.Contains(x))
              .ToArray());

            var request = new DownloadManager.Request(Android.Net.Uri.Parse(video.VideoUrl));

            request.AddRequestHeader("Referer", video.Referer);

            request.SetMimeType(mimeType);
            request.AllowScanningByMediaScanner();
            request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
            //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
            //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");
            
            //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
            request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryDownloads, invalidCharsRemoved + ".mp4");
            var dm = (DownloadManager)Application.Context.GetSystemService(Application.DownloadService);
            long id = dm.Enqueue(request);
        }
    }
}