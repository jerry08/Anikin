using System.Collections.Generic;
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
using Java.Lang;
using Java.Util;
using Toolbar = AndroidX.AppCompat.Widget.Toolbar;

namespace AniStream
{
    [Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class SettingsActivity : AppCompatActivity
    {
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

            toolbar.Click += (s, e) =>
            {
                base.OnBackPressed();
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

        public void discord(View view) 
        { 
            Discordurl("https://discord.gg/mhxsSMy2Nf"); 
        }

        private void Discordurl(string url)
        {
            Uri uriUrl = Uri.Parse(url);
            Intent launchBrowser = new Intent(Intent.ActionView, uriUrl);
            StartActivity(launchBrowser);
        }
    }
}