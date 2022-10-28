using System.Collections.Generic;
using AniStream.Models;

namespace AniStream.Settings;

public class PlayerSettings : SettingsManager
{
    public Dictionary<string, WatchedEpisode> WatchedEpisodes { get; set; } = new();

    public bool AlwaysInLandscapeMode { get; set; } = true;

    public bool SelectServerBeforePlaying { get; set; }

    public long SeekTime { get; set; } = 10000;

    public bool CursedSpeeds { get; set; }

    public int DefaultSpeedIndex { get; set; } = 5;

    public PlayerResizeMode ResizeMode { get; set; }

    public bool AutoSkipOPED { get; set; }

    public bool TimeStampsEnabled { get; set; } = true;

    public bool ShowTimeStampButton { get; set; } = true;

    public float[] GetSpeeds()
    {
        return CursedSpeeds ?
            new float[] { 1f, 1.25f, 1.5f, 1.75f, 2f, 2.5f, 3f, 4f, 5f, 10f, 25f, 50f }
            : new float[] { 0.25f, 0.33f, 0.5f, 0.66f, 0.75f, 1f, 1.25f, 1.33f, 1.5f, 1.66f, 1.75f, 2f };
    }
}

public enum PlayerResizeMode
{
    Original,
    Zoom,
    Stretch
}