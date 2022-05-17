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
using AnimeDl;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;

namespace AniStream.Utils
{
    public class Downloader : Java.Lang.Object, IDialogInterfaceOnClickListener
    {
        AnimeScraper AnimeScraper;
        EpisodesActivity Activity;
        Episode Episode;
        Anime Anime;

        public Downloader(EpisodesActivity activity, Anime anime, Episode episode)
        {
            Activity = activity;
            Episode = episode;
            Anime = anime;

            Activity.OnPermissionsResult += Activity_OnPermissionsResult;
        }

        private void Activity_OnPermissionsResult(object sender, EventArgs e)
        {
            //var test = ContextCompat.CheckSelfPermission(Activity,
            //   Manifest.Permission.WriteExternalStorage);
            //
            //var tests = ContextCompat.CheckSelfPermission(Activity,
            //   Manifest.Permission.ReadExternalStorage);

            if (ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.WriteExternalStorage)
               != Permission.Granted || ContextCompat.CheckSelfPermission(Activity,
               Manifest.Permission.ReadExternalStorage)
               != Permission.Granted)
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

        public void Download()
        {
            if (ContextCompat.CheckSelfPermission(Activity,
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
            }

            AlertDialog loadingDialog = WeebUtils.SetProgressDialog(Activity, "Getting Download Links...", false);

            AnimeScraper = new AnimeScraper();
            AnimeScraper.OnQualitiesLoaded += (s, e) =>
            {
                AlertDialog.Builder builder = new AlertDialog.Builder(Activity);
                builder.SetTitle("Download - " + Episode.EpisodeName);

                builder.SetNegativeButton("Cancel", (sender2, ev2) =>
                {

                });

                string[] items = AnimeScraper.Qualities.Select(x => x.Resolution).ToArray();
                builder.SetItems(items, this);
                builder.SetCancelable(true);
                //Dialog dialog = builder.Create();
                AlertDialog dialog = builder.Create();
                dialog.SetCanceledOnTouchOutside(false);

                loadingDialog.Dismiss();
                
                dialog.Show();
            };
            AnimeScraper.GetEpisodeLinks(Episode, false);
        }

        public void OnClick(IDialogInterface dialog, int which)
        {
            MimeTypeMap mime = MimeTypeMap.Singleton;
            string mimeType = mime.GetMimeTypeFromExtension("mp4");
            string mimeTypem4a = mime.GetMimeTypeFromExtension("m4a");

            Quality quality = AnimeScraper.Qualities[which];

            //string invalidCharRemoved = Episode.EpisodeName.Replace("[\\\\/:*?\"<>|]", "");

            var invalidChars = System.IO.Path.GetInvalidFileNameChars();

            string invalidCharsRemoved = new string(Episode.EpisodeName
              .Where(x => !invalidChars.Contains(x))
              .ToArray());

            DownloadManager.Request request = new DownloadManager.Request(Android.Net.Uri.Parse(quality.QualityUrl));

            request.AddRequestHeader("Referer", quality.Referer);

            request.SetMimeType(mimeType);
            request.AllowScanningByMediaScanner();
            request.SetNotificationVisibility(DownloadVisibility.VisibleNotifyCompleted);
            //request.SetDestinationInExternalFilesDir(mainactivity.ApplicationContext, pathToMyFolder, songFullName + ".mp3");
            //request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryMusic, songFullName + ".mp3");
            
            //request.SetDestinationInExternalPublicDir(WeebUtils.AppFolderName, invalidCharsRemoved + ".mp4");
            request.SetDestinationInExternalPublicDir(Android.OS.Environment.DirectoryDownloads, invalidCharsRemoved + ".mp4");
            DownloadManager dm = (DownloadManager)Application.Context.GetSystemService(Application.DownloadService);
            long id = dm.Enqueue(request);
        }
    }
}