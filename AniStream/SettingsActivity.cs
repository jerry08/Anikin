using System;
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
using AnimeDl.Models;
using AniStream.Settings;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Google.Android.Material.SwitchMaterial;
using Java.Lang;
using Java.Util;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
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

            var dontShow = false;
            var dontShowStr = await SecureStorage.GetAsync($"dont_ask_for_update_{packageInfo.VersionName}");
            if (!string.IsNullOrEmpty(dontShowStr))
                dontShow = System.Convert.ToBoolean(dontShowStr);

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

                //var intent = new Intent(Intent.ActionOpenDocument);
                //intent.SetType("*/*");
                //intent.AddCategory(Intent.CategoryOpenable);
                //intent.PutExtra(Intent.ExtraAllowMultiple, false);

                //var intent = new Intent(Intent.ActionGetContent);
                //intent.SetType("file/*");
                //
                //StartActivityForResult(intent, REQUEST_DIRECTORY_PICKER);

                var playerSettings = new PlayerSettings();
                await playerSettings.LoadAsync();

                var animes = await bookmarkManager.GetBookmarks();
                var rwAnimes = await rwBookmarkManager.GetBookmarks();

                var data = new
                {
                    animes,
                    rwAnimes,
                    playerSettings
                };

                var jsonData = JsonConvert.SerializeObject(data);

                //var path = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + "/test.json";
                //var tryCount = 1;
                //while (File.Exists(path))
                //{
                //    tryCount++;
                //    path = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + $"/test{tryCount}.json";
                //}

                //File.Create(path);
                //File.WriteAllText(path, jsonData);

                var tempFilePath = System.IO.Path.Combine(
                    FileSystem.CacheDirectory,
                    $"{DateTime.Now.Ticks}.json"
                );

                try
                {
                    using (var writer = File.CreateText(tempFilePath))
                    {
                        await writer.WriteLineAsync(jsonData);
                    }

                    var newFilePath = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + "/Anistream-Backup-1.json";
                    var tryCount = 1;
                    while (File.Exists(newFilePath))
                    {
                        tryCount++;
                        newFilePath = Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDownloads) + $"/Anistream-Backup-{tryCount}.json";
                    }

                    await this.CopyFileUsingMediaStore(tempFilePath, newFilePath);

                    this.ShowToast("Export completed");

                    File.Delete(tempFilePath);
                }
                catch
                {
                    this.ShowToast("Export failed");
                }
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

                    var data = JObject.Parse(json);

                    var bookmarkedAnimesJson = data["animes"]?.ToString();
                    var rwAnimesJson = data["rwAnimes"]?.ToString();
                    var playerSettingsJson = data["playerSettings"]?.ToString();

                    if (!string.IsNullOrEmpty(bookmarkedAnimesJson))
                    {
                        var animes = JsonConvert.DeserializeObject<List<Anime>?>(bookmarkedAnimesJson);

                        var existingAnimeIds = (await bookmarkManager.GetBookmarks())
                            .Select(x => x.Id);

                        if (animes is not null)
                        {
                            foreach (var anime in animes)
                            {
                                if (!existingAnimeIds.Contains(anime.Id))
                                    bookmarkManager.SaveBookmark(anime);
                            }
                        }
                    }

                    if (!string.IsNullOrEmpty(rwAnimesJson))
                    {
                        var animes = JsonConvert.DeserializeObject<List<Anime>?>(rwAnimesJson);

                        var existingAnimeIds = (await rwBookmarkManager.GetBookmarks())
                            .Select(x => x.Id);

                        if (animes is not null)
                        {
                            foreach (var anime in animes)
                            {
                                if (!existingAnimeIds.Contains(anime.Id))
                                    rwBookmarkManager.SaveBookmark(anime);
                            }
                        }
                    }

                    if (!string.IsNullOrEmpty(playerSettingsJson))
                    {
                        var playerSettings = JsonConvert.DeserializeObject<PlayerSettings?>(playerSettingsJson);
                        if (playerSettings is not null)
                        {
                            var existingPlayerSettings = new PlayerSettings();
                            await existingPlayerSettings.LoadAsync();

                            foreach (var watchedEpisode in existingPlayerSettings.WatchedEpisodes)
                            {
                                if (!playerSettings.WatchedEpisodes.ContainsKey(watchedEpisode.Key))
                                {
                                    playerSettings.WatchedEpisodes.Add(watchedEpisode.Key, watchedEpisode.Value);
                                }
                                else
                                {
                                    // Update the imported watched progress if it is less than the existing progress
                                    if (playerSettings.WatchedEpisodes[watchedEpisode.Key].WatchedPercentage <
                                        watchedEpisode.Value.WatchedPercentage)
                                    {
                                        playerSettings.WatchedEpisodes[watchedEpisode.Key] = watchedEpisode.Value;
                                    }
                                }
                            }

                            await playerSettings.SaveAsync();
                        }
                    }

                    this.ShowToast("Restore completed");
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
            var uriUrl = Android.Net.Uri.Parse(url);
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