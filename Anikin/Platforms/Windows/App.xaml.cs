using System;
using System.Diagnostics;
using System.IO;
using Microsoft.Maui;
using Microsoft.Maui.Hosting;

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
