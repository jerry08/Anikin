using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Android.App;
using AnimeDl.Models;
using AniStream.Settings;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Firebase.Auth;
using Firebase.Database;
using GoogleGson;
using Microsoft.Maui.Storage;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace AniStream.Services;

public class DataService
{
    private readonly Activity _activity;
    private readonly BookmarkManager _bookmarkManager = new("bookmarks");
    private readonly BookmarkManager _rwBookmarkManager = new("recently_watched");

    private readonly TaskCompletionSource<string> _getDataTcs = new();

    public DataService(Activity activity)
    {
        _activity = activity;
    }

    public async Task BackupAsync()
    {
        var playerSettings = new PlayerSettings();
        await playerSettings.LoadAsync();

        var animes = await _bookmarkManager.GetBookmarks();
        var rwAnimes = await _rwBookmarkManager.GetBookmarks();

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

            await _activity.CopyFileAsync(tempFilePath, newFilePath);

            _activity.ShowToast("Export completed");

            File.Delete(tempFilePath);
        }
        catch
        {
            _activity.ShowToast("Export failed");
        }
    }

    public async Task ImportAsync(string json)
    {
        try
        {
            var data = JObject.Parse(json);

            await RestoreBookmarksAsync(data["animes"]?.ToString());
            await RestoreRecentlyWatchedAsync(data["rwAnimes"]?.ToString());
            await RestorePlayerSettingsAsync(data["playerSettings"]?.ToString());

            _activity.ShowToast("Restore completed");
        }
        catch
        {
            _activity.ShowToast("Restore failed");
        }
    }

    class DataValueEventListener : Java.Lang.Object, IValueEventListener
    {
        private readonly TaskCompletionSource<string> _getDataTcs;

        public DataValueEventListener(TaskCompletionSource<string> getDataTcs)
        {
            _getDataTcs = getDataTcs;
        }

        public void OnCancelled(DatabaseError error)
        {
            _getDataTcs.TrySetResult("");
        }

        public void OnDataChange(DataSnapshot snapshot)
        {
            var json = JsonConvert.SerializeObject(snapshot.Value);

            _getDataTcs.TrySetResult(json);
        }
    }

    public async Task RestoreCloudBackupAsync()
    {
        try
        {
            var database = FirebaseDatabase.GetInstance("https://anistream-e4d6d-default-rtdb.firebaseio.com/");
            var userRef = database.Reference.Child($"users/{FirebaseAuth.Instance.CurrentUser.Uid}");

            //var data = userRef.AddValueEventListener(new DataValueEventListener());
            userRef.AddValueEventListener(new DataValueEventListener(_getDataTcs));

            var json = await _getDataTcs.Task;

            if (string.IsNullOrWhiteSpace(json))
                return;

            var data = JObject.Parse(json);

            await RestoreBookmarksAsync(data["bookmarks"]?.ToString());
            await RestoreRecentlyWatchedAsync(data["recently_watched"]?.ToString());
            await RestorePlayerSettingsAsync(data["playerSettings"]?.ToString());

            //_activity.ShowToast("Restore completed");
        }
        catch
        {
            _activity.ShowToast("Restore failed");
        }
    }

    private async Task RestoreBookmarksAsync(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return;

        var animes = JsonConvert.DeserializeObject<List<Anime>?>(json);

        var existingAnimeIds = (await _bookmarkManager.GetBookmarks())
            .Select(x => x.Id);

        if (animes is not null)
        {
            foreach (var anime in animes)
            {
                if (!existingAnimeIds.Contains(anime.Id))
                    await _bookmarkManager.SaveBookmarkAsync(anime);
            }
        }
    }

    private async Task RestoreRecentlyWatchedAsync(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return;

        var animes = JsonConvert.DeserializeObject<List<Anime>?>(json);

        var existingAnimeIds = (await _rwBookmarkManager.GetBookmarks())
            .Select(x => x.Id);

        if (animes is not null)
        {
            foreach (var anime in animes)
            {
                if (!existingAnimeIds.Contains(anime.Id))
                    await _rwBookmarkManager.SaveBookmarkAsync(anime);
            }
        }
    }

    private async Task RestorePlayerSettingsAsync(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return;

        var playerSettings = JsonConvert.DeserializeObject<PlayerSettings?>(json);
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
}