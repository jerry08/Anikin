using System;
using System.Threading.Tasks;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.Settings;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels;

public partial class ProfileViewModel : BaseViewModel
{
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

        var result = await Browser
            .Default
            .OpenAsync(
                $"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token"
            );
    }

    [RelayCommand]
    async Task GoToExtensionsSettings()
    {
        await Shell.Current.GoToAsync(nameof(ExtensionsView));
    }
}
