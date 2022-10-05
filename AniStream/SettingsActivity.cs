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
using Java.Lang;
using Java.Util;
using Newtonsoft.Json;
using Toolbar = AndroidX.AppCompat.Widget.Toolbar;

namespace AniStream
{
    [Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class SettingsActivity : AppCompatActivity
    {
        private static int REQUEST_DIRECTORY_PICKER = 1;
        private static int REQUEST_OPEN_FILE_DIALOG = 2;

        AndroidStoragePermission AndroidStoragePermission;

        Button buttonbackup, buttonrestore, buttondiscord;

        protected override void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            Xamarin.Essentials.Platform.Init(this, savedInstanceState);
            SetContentView(Resource.Layout.settings);

            Toolbar toolbar = FindViewById<Toolbar>(Resource.Id.settingstoolbar);
            SetSupportActionBar(toolbar);

            Objects.RequireNonNull(SupportActionBar, "SupportActionBar is null");

            SupportActionBar.SetDisplayHomeAsUpEnabled(true);
            SupportActionBar.SetDisplayShowHomeEnabled(true);

            //toolbar.Click += (s, e) =>
            //{
            //    base.OnBackPressed();
            //};

            buttonbackup = FindViewById<Button>(Resource.Id.buttonbackup);
            buttonrestore = FindViewById<Button>(Resource.Id.buttonrestore);
            buttondiscord = FindViewById<Button>(Resource.Id.buttondiscord);

            //AndroidStoragePermission = new AndroidStoragePermission(this);

            buttonbackup.Click += async (s, e) =>
            {
                AndroidStoragePermission = new AndroidStoragePermission(this);

                bool hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
                if (!hasStoragePermission)
                {
                    hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();
                }

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

                    Toast.MakeText(this, "Export completed", ToastLength.Short).Show();
                }
                else
                {
                    Toast.MakeText(this, "No permission granted", ToastLength.Short).Show();
                }
            };

            buttonrestore.Click += async (s, e) =>
            {
                Toast.MakeText(this, "This feature will be implemented in the next update", ToastLength.Short).Show();

                return;

                AndroidStoragePermission = new AndroidStoragePermission(this);

                bool hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
                if (!hasStoragePermission)
                {
                    hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();
                }

                if (hasStoragePermission)
                {
                    var bookmarkManager = new BookmarkManager("bookmarks");
                    var rwBookmarkManager = new BookmarkManager("recently_watched");

                    
                }
            };

            buttondiscord.Click += (s, e) =>
            {
                Discordurl("https://discord.gg/mhxsSMy2Nf");
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

        private void Discordurl(string url)
        {
            Uri uriUrl = Uri.Parse(url);
            Intent launchBrowser = new Intent(Intent.ActionView, uriUrl);
            StartActivity(launchBrowser);
        }

        protected override void OnActivityResult(int requestCode, [GeneratedEnum] Result resultCode, Intent data)
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