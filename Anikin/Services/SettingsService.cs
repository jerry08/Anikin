using System.ComponentModel;
using System.IO;
using Anikin.ViewModels.Components;
using Cogwheel;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;

namespace Anikin.Services;

[INotifyPropertyChanged]
public partial class SettingsService : SettingsBase
{
    public AppTheme AppTheme { get; set; } = AppTheme.Dark;

    public bool AlwaysCheckForUpdates { get; set; } = true;

    public string? LastProviderKey { get; set; }
    public string? LastAnimeProviderName { get; set; }

    public string? LastMangaProviderKey { get; set; }
    public string? LastMangaProviderName { get; set; }

    public string? AnilistAccessToken { get; set; }

    public GridLayoutMode EpisodesGridLayoutMode { get; set; } = GridLayoutMode.Semi;

    public GridLayoutMode MangaItemsGridLayoutMode { get; set; } = GridLayoutMode.Full;

    public bool EpisodesDescending { get; set; } = true;

    public bool MangaChaptersDescending { get; set; } = true;

    public bool ShowNonJapaneseAnime { get; set; }

    public bool ShowNonJapaneseManga { get; set; } = true;

    public bool EnableDeveloperMode { get; set; }

    public SettingsService()
        : base(Path.Combine(FileSystem.AppDataDirectory, "settings.json")) { }
}
