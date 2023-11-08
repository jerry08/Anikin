using System;
using AniStream.Services;
using AniStream.Services.AlertDialog;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;
using Microsoft.Maui.Networking;
#if ANDROID
using Snackbar = AniStream.Controls.Snackbar;
#endif

namespace AniStream;

public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = default!;

    public static IAlertService AlertService { get; private set; } = default!;

    public App(IServiceProvider provider)
    {
        InitializeComponent();

        MainPage = new AppShell();

        Services = provider;
        AlertService = Services.GetService<IAlertService>()!;

        ApplyTheme();

        AppDomain.CurrentDomain.UnhandledException += (sender, args) => {
            //UnhandledException?.Invoke(sender, args);
        };
    }

    public static bool IsOnline(bool showSnackbar = true)
    {
        if (Connectivity.Current.NetworkAccess != NetworkAccess.Internet)
        {
            if (showSnackbar)
            {
                Snackbar
                    .Make(
                        "No interent",
                        visualOptions: new SnackbarOptions()
                        {
                            BackgroundColor = Colors.Red,
                            TextColor = Colors.White,
                            ActionButtonTextColor = Colors.White
                        }
                    )
                    .Show();
            }

            return false;
        }
        else
        {
            if (showSnackbar)
            {
                Snackbar
                    .Make(
                        "You're back online",
                        visualOptions: new SnackbarOptions()
                        {
                            BackgroundColor = Colors.Green,
                            TextColor = Colors.White,
                            ActionButtonTextColor = Colors.White
                        }
                    )
                    .Show();
            }

            return true;
        }
    }

    public static void ApplyTheme(bool force = false)
    {
        if (Current is null)
            return;

        var preferenceService = new PreferenceService();
        preferenceService.Load();

        if (force)
        {
            Current.UserAppTheme = AppTheme.Unspecified;
        }

        Current.UserAppTheme = preferenceService.AppTheme;
    }

    protected override void OnAppLinkRequestReceived(Uri uri)
    {
        base.OnAppLinkRequestReceived(uri);
    }
}
