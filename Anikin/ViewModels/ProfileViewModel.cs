using System.Threading.Tasks;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.Settings;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels;

public partial class ProfileViewModel : BaseViewModel
{
    private readonly AniClient _aniClient;

    [ObservableProperty]
    private SettingsService _settings = default!;

    [ObservableProperty]
    string? _homeAnimeListImage;

    [ObservableProperty]
    string? _homeMangaListImage;

    [ObservableProperty]
    User? _user;

    public ProfileViewModel(AniClient aniClient, SettingsService settingsService)
    {
        _aniClient = aniClient;

        Settings = settingsService;
        Settings.Load();

        Settings.PropertyChanged += (_, _) =>
        {
            Settings.Save();

            App.IsInDeveloperMode = Settings.EnableDeveloperMode;
        };

        HomeAnimeListImage ??= "https://bit.ly/31bsIHq";
        HomeMangaListImage ??= "https://bit.ly/2ZGfcuG";

        Load();
    }

    protected override async Task LoadCore()
    {
        //return base.LoadCore();

        if (string.IsNullOrWhiteSpace(Settings.AnilistAccessToken))
            return;

        try
        {
            User = await _aniClient.GetAuthenticatedUserAsync();
            if (User is null)
                return;

            var result = await _aniClient.GetUserEntriesAsync(
                User.Id,
                new()
                {
                    Type = MediaType.Anime,
                    Sort = MediaEntrySort.Score,
                    SortDescending = true
                }
            );

            if (result.Data.Length > 0)
            {
                HomeAnimeListImage = result.Data[0].Media?.BannerImageUrl?.ToString();
            }

            result = await _aniClient.GetUserEntriesAsync(
                User.Id,
                new()
                {
                    Type = MediaType.Manga,
                    Sort = MediaEntrySort.Score,
                    SortDescending = true
                }
            );

            if (result.Data.Length > 0)
            {
                HomeMangaListImage = result.Data[0].Media?.BannerImageUrl?.ToString();
            }
        }
        catch { }
    }

    [RelayCommand]
    private void ThemeSelected(int index)
    {
        var selectedTheme = (AppTheme)index;

        if (Settings.AppTheme == selectedTheme)
        {
            // For some reason, EventToCommandBehavior does not get removed
            // when calling `new AppShell()`
            return;
        }

        Settings.AppTheme = selectedTheme;
        Settings.Save();

        App.ApplyTheme();

        if (Application.Current is not null)
            Application.Current.MainPage = new AppShell();
    }

    [RelayCommand]
    async Task LoginWithAnilist()
    {
        //try
        //{
        //    var fontRegistrar = App.Services.GetService<IFontRegistrar>();
        //    var test1 = fontRegistrar.GetFont("Material");
        //
        //    App.AlertService.ShowAlert("test1", test1);
        //
        //    fontRegistrar?.Register(
        //        @"C:\Users\jerem\source\repos\MAUI\Anikin\Anikin\Resources\Fonts\MaterialIconsRound-Regular.otf",
        //        "Material"
        //    );
        //
        //    test1 = fontRegistrar.GetFont("Material");
        //
        //    App.AlertService.ShowAlert("test2", test1);
        //}
        //catch (Exception ex)
        //{
        //    App.AlertService.ShowAlert("Error", $"{ex}");
        //}
        //
        //return;

        var clientID = "14733";
        var url =
            $"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token";

#if WINDOWS
        //await Windows.System.Launcher.LaunchUriAsync(new(url));
        await Browser.Default.OpenAsync(url);
#else
        await Shell.Current.GoToAsync(nameof(AnilistLoginView));
#endif
    }

    [RelayCommand]
    async Task GoToExtensionsSettings()
    {
        await Shell.Current.GoToAsync(nameof(ExtensionsView));
    }
}
