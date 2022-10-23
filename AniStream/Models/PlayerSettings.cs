namespace AniStream.Models;

public class PlayerSettings
{
    public bool AlwaysInLandscapeMode { get; set; } = true;

    public bool SelectServerBeforePlaying { get; set; } = false;

    public long SeekTime { get; set; } = 15000;

    public void Load()
    {
        //TODO: Load settings from json file later
    }
}