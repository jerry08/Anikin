using System.IO;
using Cogwheel;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;

namespace AniStream.Services;

public class PreferenceService : SettingsBase
{
    public AppTheme AppTheme { get; set; } = AppTheme.Dark;

    public PreferenceService()
        : base(Path.Combine(FileSystem.AppDataDirectory, "preference.json")) { }
}
