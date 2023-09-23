using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using Android.App;
using Android.Runtime;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Firebase.Auth;
using Firebase.Database;
using Juro.Models.Anime;
using Microsoft.Maui.Storage;

namespace AniStream.Services;

public class DataService
{
    private readonly Activity _activity;
    private readonly BookmarkManager _bookmarkManager = new("bookmarks");
    private readonly BookmarkManager _rwBookmarkManager = new("recently_watched");

    private readonly TaskCompletionSource<string?> _getDataTcs = new();

    public DataService(Activity activity)
    {
        _activity = activity;
    }

    public async Task BackupAsync()
    {
        var playerSettings = new PlayerSettings();
        playerSettings.Load();

        var animes = (await _bookmarkManager.GetAllBookmarksAsync())
            .Select(x => new
            {
                x.Id,
                x.Title,
                x.Category,
                x.Site,
                x.Image
            });

        var rwAnimes = (await _rwBookmarkManager.GetAllBookmarksAsync())
            .Select(x => new
            {
                x.Id,
                x.Title,
                x.Category,
                x.Site,
                x.Image
            });

        var data = new
        {
            animes,
            rwAnimes,
            playerSettings
        };

        var jsonData = JsonSerializer.Serialize(data);

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
            var data = JsonNode.Parse(json)!;

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
        private readonly TaskCompletionSource<string?> _getDataTcs;

        public DataValueEventListener(TaskCompletionSource<string?> getDataTcs)
        {
            _getDataTcs = getDataTcs;
        }

        public void OnCancelled(DatabaseError error)
        {
            _getDataTcs.TrySetResult(null);
        }

        public void OnDataChange(DataSnapshot snapshot)
        {
            try
            {
                var dictionary = ((JavaDictionary?)snapshot.Value)?.ToDictionary();

                var serializeOptions = new JsonSerializerOptions
                {
                    Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                    //Encoder = JavaScriptEncoder.Create(new TextEncoderSettings(System.Text.Unicode.UnicodeRanges.All))
                };

                var json = JsonSerializer.Serialize(dictionary, serializeOptions);

                _getDataTcs.TrySetResult(json);
            }
            catch
            {
                _getDataTcs.TrySetResult(null);
            }
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

            var data = JsonNode.Parse(json)!;

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

        var animes = JsonSerializer.Deserialize<List<AnimeInfo>?>(json);

        var existingAnimeIds = (await _bookmarkManager.GetAllBookmarksAsync())
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

        var animes = JsonSerializer.Deserialize<List<AnimeInfo>?>(json);

        var existingAnimeIds = (await _rwBookmarkManager.GetAllBookmarksAsync())
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

        var playerSettings = JsonSerializer.Deserialize<PlayerSettings?>(json);
        if (playerSettings is not null)
        {
            var existingPlayerSettings = new PlayerSettings();
            existingPlayerSettings.Load();

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

            playerSettings.Save();
        }
    }
}