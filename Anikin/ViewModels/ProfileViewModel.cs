using System.Threading.Tasks;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.Settings;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels;

public partial class ProfileViewModel : BaseViewModel
{
    [ObservableProperty]
    private SettingsService _settings = default!;

    public ProfileViewModel(SettingsService settingsService)
    {
        Settings = settingsService;
        Settings.Load();

        Settings.PropertyChanged += (_, _) =>
        {
            Settings.Save();

            App.IsInDeveloperMode = Settings.EnableDeveloperMode;
        };
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

        await Shell.Current.GoToAsync(nameof(AnilistLoginView));
        return;

        var clientID = "14733";

        var result = await Browser.Default.OpenAsync(
            $"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token"
        );
    }

    [RelayCommand]
    async Task GoToExtensionsSettings()
    {
        await Shell.Current.GoToAsync(nameof(ExtensionsView));
    }
}
