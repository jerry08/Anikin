using System;
using System.Text.RegularExpressions;
using Anikin.Services;
using Berry.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace Anikin.Views;

public partial class AnilistLoginView
{
    private readonly SettingsService _settingsService = new();

    public AnilistLoginView()
    {
        InitializeComponent();

        SetMargins();

        DeviceDisplay.Current.MainDisplayInfoChanged += (_, _) => SetMargins();
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        var clientID = "14733";

        webView.Source =
            $"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token";

        webView.Navigated += (s, e) =>
        {
            //var res = e.Result;

            var regex = new Regex("""(?<=access_token=).+(?=&token_type)""");
            var token = regex.Match(e.Url).Value;

            if (!string.IsNullOrWhiteSpace(token))
            {
                _settingsService.Load();
                _settingsService.AnilistAccessToken = token;
                _settingsService.Save();

                if (Application.Current is not null)
                    Application.Current.MainPage = new AppShell();
            }
        };
    }

    protected override void OnDisappearing()
    {
        base.OnDisappearing();

        App.ApplyTheme(true);
    }

    private void SetMargins()
    {
        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;

        var navigationBarHeight = (int)(
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density
        );

        var marginTop = 0.0;
        var marginBottom = 0.0;
        var marginLeft = 0.0;
        var marginRight = 0.0;

        if (statusBarHeight > 0)
            marginTop = statusBarHeight;

        if (navigationBarHeight > 0)
        {
            if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
            {
                marginBottom = navigationBarHeight;
            }
            else
            {
                marginLeft = navigationBarHeight;
                marginRight = navigationBarHeight;
            }
        }

        Content.Margin = new(marginLeft, marginTop, marginRight, marginBottom);
    }

    private async void CloseButton_Clicked(object sender, EventArgs e)
    {
        await Shell.Current.Navigation.PopAsync();
    }
}
