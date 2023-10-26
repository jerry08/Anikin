using System.ComponentModel;
using System.IO;
using AniStream.ViewModels.Components;
using Cogwheel;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;
using PropertyChanged;

namespace AniStream.Services;

[AddINotifyPropertyChangedInterface]
public partial class SettingsService : SettingsBase, INotifyPropertyChanged
{
    public AppTheme AppTheme { get; set; } = AppTheme.Dark;

    public bool AlwaysCheckForUpdates { get; set; } = true;

    public string? LastProviderKey { get; set; }

    public string? AnilistAccessToken { get; set; }

    public GridLayoutMode EpisodesGridLayoutMode { get; set; } = GridLayoutMode.Semi;

    public SettingsService()
        : base(Path.Combine(FileSystem.AppDataDirectory, "settings.json"))
    {
    }
}