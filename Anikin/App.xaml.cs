using System;
using System.Linq;
using Anikin.Services;
using Anikin.Services.AlertDialog;
using Berry.Maui.Behaviors;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Behaviors;
using CommunityToolkit.Maui.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;
using Microsoft.Maui.Networking;
using NavigationBarStyle = Berry.Maui.Behaviors.NavigationBarStyle;

namespace Anikin;

public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = default!;
    public static IAlertService AlertService { get; private set; } = default!;

    public static bool IsChangingTheme { get; set; }

    public static bool IsInDeveloperMode { get; set; }

    public App(IServiceProvider provider)
    {
        InitializeComponent();

        Services = provider;

        AlertService = Services.GetRequiredService<IAlertService>();

        var settingsService = Services.GetRequiredService<SettingsService>();
        settingsService.Load();

        IsInDeveloperMode = settingsService.EnableDeveloperMode;

        ApplyTheme();

        AppDomain.CurrentDomain.UnhandledException += (sender, args) =>
        {
            var tt = "";

            //UnhandledException?.Invoke(sender, args);

            //var path = Path.Join(Environment.CurrentDirectory, $"error_log.txt");
            //var path = Path.Join(AppDomain.CurrentDomain.BaseDirectory, $"error_log.txt");
            //File.WriteAllText(path, $"{args}");
        };
    }

    private Window? CurrentWindow { get; set; }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        if (CurrentWindow is not null && IsChangingTheme)
        {
            IsChangingTheme = false;
            return CurrentWindow;
        }

        CurrentWindow = new(new AppShell());

        return CurrentWindow;
    }

    protected override void OnStart()
    {
        base.OnStart();

#if WINDOWS && !DEBUG
        // Must call `register` for WinUI notification manager if the app is unpackaged
        // https://stackoverflow.com/questions/76020847/right-way-to-publish-winui3-app-in-single-exe-file
        // https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/notifications/app-notifications/app-notifications-quickstart?tabs=cs
        // (Snackbar doesn't show, only toast?!)
        Microsoft.Windows.AppNotifications.AppNotificationManager.Default.Register();
#endif
    }

    public static bool IsOnline(bool showSnackbar = true)
    {
        if (Connectivity.Current.NetworkAccess != NetworkAccess.Internet)
        {
            if (showSnackbar)
            {
#if WINDOWS
                Snackbar.Make("No interent").Show();
#else
                Snackbar
                    .Make(
                        "No interent",
                        visualOptions: new SnackbarOptions()
                        {
                            BackgroundColor = Colors.Red,
                            TextColor = Colors.White,
                            ActionButtonTextColor = Colors.White,
                        }
                    )
                    .Show();
#endif
            }

            return false;
        }
        else
        {
            if (showSnackbar)
            {
#if WINDOWS
                Snackbar.Make("No interent").Show();
#else
                Snackbar
                    .Make(
                        "You're back online",
                        visualOptions: new SnackbarOptions()
                        {
                            BackgroundColor = Colors.Green,
                            TextColor = Colors.White,
                            ActionButtonTextColor = Colors.White,
                        }
                    )
                    .Show();
#endif
            }

            return true;
        }
    }

    public static void ApplyTheme(bool force = false)
    {
        if (Current is null)
            return;

        var settingsService = Services.GetRequiredService<SettingsService>();
        settingsService.Load();

        if (force)
        {
            Current.UserAppTheme = AppTheme.Unspecified;
        }

        Current.UserAppTheme = settingsService.AppTheme;

        //if (Shell.Current.CurrentPage is not null)
        //{
        //    Berry.Maui.Controls.Insets.SetEdgeToEdge(Shell.Current.CurrentPage, true);
        //    Berry.Maui.Controls.Insets.SetStatusBarStyle(
        //        Shell.Current.CurrentPage,
        //        Berry.Maui.Controls.StatusBarStyle.DarkContent
        //    );
        //}
    }

    public static void RefreshCurrentPageBehaviors()
    {
        var primaryColor = Current?.Resources["Primary"];
        var gray900Color = Current?.Resources["Gray900"];

#if !MACCATALYST
#pragma warning disable CA1416
        foreach (var behavior in Shell.Current.Behaviors.OfType<StatusBarBehavior>())
        {
            behavior.SetAppTheme(
                StatusBarBehavior.StatusBarColorProperty,
                primaryColor,
                gray900Color
            );
            behavior.StatusBarStyle = StatusBarStyle.LightContent;
        }
#pragma warning restore CA1416
#endif

        foreach (var behavior in Shell.Current.Behaviors.OfType<NavigationBarBehavior>())
        {
            behavior.SetAppTheme(
                NavigationBarBehavior.NavigationBarColorProperty,
                Colors.White,
                gray900Color
            );
            behavior.SetAppTheme(
                NavigationBarBehavior.NavigationBarStyleProperty,
                NavigationBarStyle.DarkContent,
                NavigationBarStyle.LightContent
            );
        }
    }

    protected override void OnAppLinkRequestReceived(Uri uri)
    {
        base.OnAppLinkRequestReceived(uri);
    }
}
