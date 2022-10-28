namespace AniStream.Settings;

/// <summary>
/// Configuration for <see cref="SettingsManager"/>
/// </summary>
public class Configuration
{
    /// <summary>
    /// Key of the settings file
    /// </summary>
    public string Key { get; set; } = "Settings";

    /// <summary>
    /// Whether to throw an exception when the settings file cannot be saved
    /// </summary>
    public bool ThrowIfCannotSave { get; set; } = true;

    /// <summary>
    /// Whether to throw an exception when the settings file cannot be loaded
    /// </summary>
    public bool ThrowIfCannotLoad { get; set; } = false;
}