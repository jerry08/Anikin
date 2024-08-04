using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using Anikin.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui;
using Microsoft.Maui.Hosting;
using Microsoft.UI.Xaml;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace Anikin.WinUI;

/// <summary>
/// Provides application-specific behavior to supplement the default Application class.
/// </summary>
public partial class App : MauiWinUIApplication
{
    /// <summary>
    /// Initializes the singleton application object.  This is the first line of authored code
    /// executed, and as such is the logical equivalent of main() or WinMain().
    /// </summary>
    public App()
    {
        this.InitializeComponent();

        UnhandledException += App_UnhandledException;
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        base.OnLaunched(args);

        var mainInstance = Microsoft.Windows.AppLifecycle.AppInstance.FindOrRegisterForKey("main");

        if (!mainInstance.IsCurrent)
        {
            var activatedArgs = Microsoft
                .Windows.AppLifecycle.AppInstance.GetCurrent()
                .GetActivatedEventArgs();

            if (
                activatedArgs.Data
                is Windows.ApplicationModel.Activation.ProtocolActivatedEventArgs token
            )
            {
                //var slicedToken = SlicedToken(token.Uri.ToString());

                var settingsService = Services.GetRequiredService<SettingsService>();
                settingsService.Load();

                var regex = new Regex("""(?<=access_token=).+(?=&token_type)""");
                var tokenStr = regex.Match(token.Uri.ToString()).Value;

                if (!string.IsNullOrWhiteSpace(tokenStr))
                {
                    settingsService.Load();
                    settingsService.AnilistAccessToken = tokenStr;
                    settingsService.Save();
                }

                await mainInstance.RedirectActivationToAsync(activatedArgs);
                Process.GetProcessById((int)mainInstance.ProcessId).Kill();
            }
        }
    }

    private string SlicedToken(string rawToken)
    {
        //var token = rawToken.Replace("animoe:/auth#access_token=", "");
        var token = rawToken.Replace("anistream://anilist/#access_token=", "");
        token = token.Split('&')[0];
        return token;
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

    private void App_UnhandledException(
        object sender,
        Microsoft.UI.Xaml.UnhandledExceptionEventArgs e
    )
    {
        e.Handled = true;

        try
        {
            //var path = Path.Join(Environment.CurrentDirectory, "error_log.txt");
            var path = Path.Join(AppDomain.CurrentDomain.BaseDirectory, "error_log.txt");
            File.AppendAllText(
                path,
                $"{DateTime.Now:F}{Environment.NewLine}{e.Exception}{Environment.NewLine}{Environment.NewLine}"
            );
        }
        catch { }

        Debug.WriteLine("Exception catched");

        Anikin.App.AlertService.ShowAlert("Error", $"{e.Exception}");
    }
}
