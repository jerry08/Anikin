﻿using System;
using Anikin.Services;
using Anikin.Services.AlertDialog;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;
using Microsoft.Maui.Networking;

namespace Anikin;

public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = default!;

    public static IAlertService AlertService { get; private set; } = default!;

    public static bool IsInDeveloperMode { get; set; }

    public App(IServiceProvider provider)
    {
        InitializeComponent();

        MainPage = new AppShell();

        Services = provider;

        AlertService = Services.GetRequiredService<IAlertService>();

        var settingsService = Services.GetRequiredService<SettingsService>();
        settingsService.Load();

        IsInDeveloperMode = settingsService.EnableDeveloperMode;

        ApplyTheme();

        AppDomain.CurrentDomain.UnhandledException += (sender, args) => {
            //UnhandledException?.Invoke(sender, args);

            //var path = Path.Join(Environment.CurrentDirectory, $"error_log.txt");
            //var path = Path.Join(AppDomain.CurrentDomain.BaseDirectory, $"error_log.txt");
            //File.WriteAllText(path, $"{args}");
        };
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

        // Initialize providers
        new ProviderService().Initialize();
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
                            ActionButtonTextColor = Colors.White
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
                            ActionButtonTextColor = Colors.White
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

    protected override void OnAppLinkRequestReceived(Uri uri)
    {
        base.OnAppLinkRequestReceived(uri);
    }
}
