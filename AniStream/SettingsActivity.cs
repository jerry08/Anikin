using System.Collections.Generic;
using System.IO;
using System.Linq;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Database.Sqlite;
using Android.Graphics;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AndroidX.AppCompat.App;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Google.Android.Material.SwitchMaterial;
using Java.Lang;
using Java.Util;
using Newtonsoft.Json;
using Xamarin.Essentials;
using Toolbar = AndroidX.AppCompat.Widget.Toolbar;

namespace AniStream
{
    [Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class SettingsActivity : AppCompatActivity
    {
        private static int REQUEST_DIRECTORY_PICKER = 1;
        private static int REQUEST_OPEN_FILE_DIALOG = 2;

        AndroidStoragePermission AndroidStoragePermission = default!;

        Button buttonbackup = default!;
        Button buttonrestore = default!;
        Button buttondiscord = default!;
        Button buttongithub = default!;
        Button button_check_for_updates = default!;
        SwitchMaterial dontAskForUpdate = default!;

        protected override async void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            Platform.Init(this, savedInstanceState);
            SetContentView(Resource.Layout.settings);

            var toolbar = FindViewById<Toolbar>(Resource.Id.settingstoolbar);
            SetSupportActionBar(toolbar);

            Objects.RequireNonNull(SupportActionBar, "SupportActionBar is null");

            SupportActionBar!.SetDisplayHomeAsUpEnabled(true);
            SupportActionBar.SetDisplayShowHomeEnabled(true);

            //toolbar.Click += (s, e) =>
            //{
            //    base.OnBackPressed();
            //};

            buttonbackup = FindViewById<Button>(Resource.Id.buttonbackup)!;
            buttonrestore = FindViewById<Button>(Resource.Id.buttonrestore)!;
            buttongithub = FindViewById<Button>(Resource.Id.buttongithub)!;
            buttondiscord = FindViewById<Button>(Resource.Id.buttondiscord)!;
            button_check_for_updates = FindViewById<Button>(Resource.Id.button_check_for_updates)!;
            dontAskForUpdate = FindViewById<SwitchMaterial>(Resource.Id.dontAskForUpdate)!;

            var packageInfo = PackageManager!.GetPackageInfo(PackageName!, 0)!;

            bool dontShow = false;
            var dontShowStr = await SecureStorage.GetAsync($"dont_ask_for_update_{packageInfo.VersionName}");
            if (!string.IsNullOrEmpty(dontShowStr))
                dontShow = System.Convert.ToBoolean(dontShowStr);
            
            dontAskForUpdate.Checked = dontShow;

            dontAskForUpdate.CheckedChange += async (s, e) =>
            {
                await SecureStorage.SetAsync($"dont_ask_for_update_{packageInfo.VersionName}", dontAskForUpdate.Checked.ToString());
            };

            //AndroidStoragePermission = new AndroidStoragePermission(this);

            buttonbackup.Click += async (s, e) =>
            {
                AndroidStoragePermission = new AndroidStoragePermission(this);

                bool hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
                if (!hasStoragePermission)
                    hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();
                
                if (hasStoragePermission)
                {
                    //var intent = new Intent(Intent.ActionOpenDocument);
                    //intent.SetType("*/*");
                    //intent.AddCategory(Intent.CategoryOpenable);
                    //intent.PutExtra(Intent.ExtraAllowMultiple, false);

                    //var intent = new Intent(Intent.ActionGetContent);
                    //intent.SetType("file/*");
                    //
                    //StartActivityForResult(intent, REQUEST_DIRECTORY_PICKER);

                    var bookmarkManager = new BookmarkManager("bookmarks");
                    var rwBookmarkManager = new BookmarkManager("recently_watched");

                    var animes = await bookmarkManager.GetBookmarks();
                    var rwAnimes = await rwBookmarkManager.GetBookmarks();

                    var data = new
                    {
                        animes,
                        rwAnimes
                    };

                    var jsonData = JsonConvert.SerializeObject(data);

                    var path = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + "/test.json";
                    int tryCount = 1;
                    while (File.Exists(path))
                    {
                        tryCount++;
                        path = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + $"/test{tryCount}.json";
                    }

                    //File.Create(path);
                    //File.WriteAllText(path, jsonData);

                    using (StreamWriter sw = File.CreateText(path))
                    {
                        sw.WriteLine(jsonData);
                    }

                    this.ShowToast("Export completed");
                }
                else
                {
                    this.ShowToast("No permission granted");
                }
            };

            buttonrestore.Click += async (s, e) =>
            {
                this.ShowToast("This feature will be implemented in the next update");

                return;

                AndroidStoragePermission = new AndroidStoragePermission(this);

                bool hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
                if (!hasStoragePermission)
                    hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();

                if (hasStoragePermission)
                {
                    var bookmarkManager = new BookmarkManager("bookmarks");
                    var rwBookmarkManager = new BookmarkManager("recently_watched");
                }
            };

            buttongithub.Click += (s, e) =>{ OpenLink("https://github.com/jerry08/AniStream"); };
            
            buttondiscord.Click += (s, e) =>{ OpenLink("https://discord.gg/mhxsSMy2Nf"); };

            button_check_for_updates.Click += async (s, e) =>
            {
                var dialog = WeebUtils.SetProgressDialog(this, "Checking for updates", false);
                dialog.Show();

                var updater = new AppUpdater();
                var updateAvailable = await updater.CheckAsync(this);

                dialog.Dismiss();

                if (!updateAvailable)
                    this.ShowToast("No updates available");
            };

            //Button2 = FindViewById<Button>(Resource.Id.buttonrestore);
            //Button2.Click += (s, e) =>
            //{
            //    ExportData();
            //};
            //
            //SignInButton = FindViewById<Button>(Resource.Id.buttonbackup);
            //SignInButton.Click += (s, e) =>
            //{
            //    SignIn();
            //};
        }

        public override bool OnSupportNavigateUp()
        {
            base.OnBackPressed();
            return base.OnSupportNavigateUp();
        }

        private void SignIn()
        {
            
        }

        private void HandleSignInResult(Intent result) 
        {
            
        }

        private void OpenLink(string url)
        {
            var uriUrl = Uri.Parse(url);
            var launchBrowser = new Intent(Intent.ActionView, uriUrl);
            StartActivity(launchBrowser);
        }

        protected override void OnActivityResult(int requestCode, [GeneratedEnum] Result resultCode, Intent? data)
        {
            base.OnActivityResult(requestCode, resultCode, data);
            AndroidStoragePermission.OnActivityResult(requestCode, resultCode, data);
        }

        public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Permission[] grantResults)
        {
            base.OnRequestPermissionsResult(requestCode, permissions, grantResults);
            AndroidStoragePermission.OnRequestPermissionsResult(requestCode, permissions, grantResults);
        }
    }
}