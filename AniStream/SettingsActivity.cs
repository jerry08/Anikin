using System;
using System.Collections.Generic;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Widget;
using AndroidX.AppCompat.App;
using AniStream.Services;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Firebase.Auth;
using Google.Android.Material.SwitchMaterial;
using Java.Util;
using Jerro.Maui.GoogleClient;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Devices;
using Microsoft.Maui.Storage;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using Toolbar = AndroidX.AppCompat.Widget.Toolbar;

namespace AniStream;

[Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public class SettingsActivity : AppCompatActivity
{
    AndroidStoragePermission? AndroidStoragePermission;

    Button buttonbackup = default!;
    Button buttonrestore = default!;
    Button buttondiscord = default!;
    Button buttongithub = default!;
    Button button_check_for_updates = default!;
    SwitchMaterial dontAskForUpdate = default!;
    Button button_login = default!;

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

        var dontShow = false;
        var dontShowStr = await SecureStorage.GetAsync($"dont_ask_for_update_{packageInfo.VersionName}");
        if (!string.IsNullOrEmpty(dontShowStr))
            dontShow = Convert.ToBoolean(dontShowStr);

        dontAskForUpdate.Checked = dontShow;

        dontAskForUpdate.CheckedChange += async (s, e) => await SecureStorage.SetAsync($"dont_ask_for_update_{packageInfo.VersionName}", dontAskForUpdate.Checked.ToString());

        //AndroidStoragePermission = new AndroidStoragePermission(this);

        var bookmarkManager = new BookmarkManager("bookmarks");
        var rwBookmarkManager = new BookmarkManager("recently_watched");

        buttonbackup.Click += async (s, e) =>
        {
            AndroidStoragePermission = new AndroidStoragePermission(this);

            var hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
            if (!hasStoragePermission)
                hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();

            if (!hasStoragePermission)
            {
                this.ShowToast("Storage permission not granted");
                return;
            }

            var dataService = new DataService(this);
            await dataService.BackupAsync();
        };

        buttonrestore.Click += async (s, e) =>
        {
            AndroidStoragePermission = new AndroidStoragePermission(this);

            var hasStoragePermission = AndroidStoragePermission.HasStoragePermission();
            if (!hasStoragePermission)
                hasStoragePermission = await AndroidStoragePermission.RequestStoragePermission();

            if (!hasStoragePermission)
            {
                this.ShowToast("Storage permission not granted");
                return;
            }

            var customFileType =
                new FilePickerFileType(new Dictionary<DevicePlatform, IEnumerable<string>>
                {
                    { DevicePlatform.Android, new[] { "application/json" } },
                });

            var options = new PickOptions
            {
                PickerTitle = "Please select a json file",
                FileTypes = customFileType,
            };

            var result = await FilePicker.PickAsync(options);
            if (result is null)
                return;

            try
            {
                var stream = await result.OpenReadAsync();
                var json = await stream.ToStringAsync();

                var dataService = new DataService(this);
                await dataService.ImportAsync(json);
            }
            catch
            {
                this.ShowToast("Restore failed");
            }
        };

        buttongithub.Click += (s, e) => OpenLink("https://github.com/jerry08/AniStream");
        buttondiscord.Click += (s, e) => OpenLink("https://discord.gg/mhxsSMy2Nf");

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

        GoogleClientManager.Initialize(
            this,
            null,
            "1018117642382-c6avui7h23fdfd4rgc20mo70bn4rljob.apps.googleusercontent.com"
        );

        button_login = FindViewById<Button>(Resource.Id.button_login)!;
        button_login.Click += (s, e) =>
        {
            if (FirebaseAuth.Instance.CurrentUser is null)
                SignInWithGoogle();
            else
                Logout();
        };

        if (FirebaseAuth.Instance.CurrentUser is null)
            button_login.Text = "Sign in with Google";
        else
            button_login.Text = "Log out";
    }

    private void Logout()
    {
        var alert = new AlertDialog.Builder(this, Resource.Style.DialogTheme);
        alert.SetMessage($"Are you sure you want to log out of {FirebaseAuth.Instance.CurrentUser.Email}?");
        alert.SetPositiveButton("Yes", (s, e) =>
        {
            FirebaseAuth.Instance.SignOut();
            CrossGoogleClient.Current.Logout();

            this.ShowToast("Signed out");

            button_login.Text = "Sign in with Google";
        });

        alert.SetNegativeButton("Cancel", (s, e) => { });

        alert.SetCancelable(false);
        var dialog = alert.Create();
        dialog.Show();
    }

    private async void SignInWithGoogle()
    {
        var googleClientManager = CrossGoogleClient.Current;

        googleClientManager.OnLogin -= GoogleClientManager_OnLogin;
        googleClientManager.OnLogin += GoogleClientManager_OnLogin;

        try
        {
            await googleClientManager.LoginAsync();

            // Signed in

            // Check if user is signed in (non-null) and update UI accordingly.
            var currentUser = FirebaseAuth.Instance.CurrentUser;
            if (currentUser is null)
            {
                // Sign in
                var firebaseCredential = GoogleAuthProvider.GetCredential(
                    googleClientManager.CurrentUser.IdToken,
                    null
                );
                var result = await FirebaseAuth.Instance.SignInWithCredentialAsync(firebaseCredential);

                if (FirebaseAuth.Instance.CurrentUser is null)
                {
                    this.ShowToast("Failed to sign in");
                }
                else
                {
                    this.ShowToast("Signed in");

                    // Resore backup from firebase database
                    var dataService = new DataService(this);
                    await dataService.RestoreCloudBackupAsync();
                }
            }
        }
        catch
        {
            // Sign in failed
            this.ShowToast("Failed to sign in");
        }
    }

    private async void GoogleClientManager_OnLogin(object? sender, GoogleClientResultEventArgs<GoogleUser> e)
    {

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
        var uriUrl = Android.Net.Uri.Parse(url);
        var launchBrowser = new Intent(Intent.ActionView, uriUrl);
        StartActivity(launchBrowser);
    }

    protected override void OnActivityResult(int requestCode, [GeneratedEnum] Result resultCode, Intent? data)
    {
        base.OnActivityResult(requestCode, resultCode, data);

        AndroidStoragePermission?.OnActivityResult(requestCode, resultCode, data);
        GoogleClientManager.OnAuthCompleted(requestCode, resultCode, data);
    }

    public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Permission[] grantResults)
    {
        base.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        AndroidStoragePermission?.OnRequestPermissionsResult(requestCode, permissions, grantResults);
    }
}