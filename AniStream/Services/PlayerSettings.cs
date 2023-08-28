using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using AniStream.Models;
using Firebase.Auth;
using Firebase.Database;
using JCogwheel;
using Microsoft.Maui.Storage;

namespace AniStream.Services;

public class PlayerSettings : SettingsBase
{
    public Dictionary<string, WatchedEpisode> WatchedEpisodes { get; set; } = new();

    public bool AlwaysInLandscapeMode { get; set; } = true;

    public bool SelectServerBeforePlaying { get; set; }

    /// <summary>
    /// Seek time in milliseconds.
    /// </summary>
    public long SeekTime { get; set; } = 10000;

    public bool CursedSpeeds { get; set; }

    public int DefaultSpeedIndex { get; set; } = 5;

    public int FontSize { get; set; } = 20;

    public PlayerResizeMode ResizeMode { get; set; }

    public bool AutoSkipOPED { get; set; }

    public bool TimeStampsEnabled { get; set; } = true;

    public bool ShowTimeStampButton { get; set; } = true;

    public bool DoubleTap { get; set; } = true;

    public long ControllerDuration { get; set; } = 200;

    public float[] GetSpeeds()
    {
        return CursedSpeeds ?
            new float[] { 1f, 1.25f, 1.5f, 1.75f, 2f, 2.5f, 3f, 4f, 5f, 10f, 25f, 50f }
            : new float[] { 0.25f, 0.33f, 0.5f, 0.66f, 0.75f, 1f, 1.25f, 1.33f, 1.5f, 1.66f, 1.75f, 2f };
    }

    public PlayerSettings()
        : base(Path.Combine(FileSystem.AppDataDirectory, "PlayerSettings.dat"))
    {
    }

    public override void Save()
    {
        base.Save();
        SaveToCloudAsync();
    }

    private async void SaveToCloudAsync()
    {
        // Check if user is signed in (non-null)
        var currentUser = FirebaseAuth.Instance.CurrentUser;
        if (currentUser is null)
            return;

        var database = FirebaseDatabase.GetInstance("https://anistream-e4d6d-default-rtdb.firebaseio.com/");
        var userRef = database.Reference.Child($"users/{FirebaseAuth.Instance.CurrentUser.Uid}");

        //userRef.AddListenerForSingleValueEvent(new DeleteValueEventListener());

        //await userRef.Child("bookmarks").SetValueAsync("test1");
        //await userRef.Child("bookmarks").Push().SetValueAsync("test1");

        var data = JsonSerializer.Serialize(this);

        await userRef.Child("playerSettings").SetValueAsync(data);
    }
}

public enum PlayerResizeMode
{
    Original,
    Zoom,
    Stretch
}