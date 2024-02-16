using System.Net.Http;
using System.Net.Http.Headers;
using Anikin.Services;
using Anikin.Services.AlertDialog;
using Anikin.ViewModels;
using Anikin.ViewModels.Home;
using Anikin.ViewModels.Manga;
using Anikin.Views;
using Anikin.Views.Home;
using Anikin.Views.Manga;
using Anikin.Views.Settings;
using Berry.Maui;
using CommunityToolkit.Maui;
using CommunityToolkit.Maui.Markup;
using Jita.AniList;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using Microsoft.Maui.LifecycleEvents;
using Woka;

#if ANDROID
using Microsoft.Maui.Controls.Compatibility.Platform.Android;
#endif

namespace Anikin;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .UseMauiCommunityToolkitMarkup()
            .UseBerry()
            .UseBerryMediaElement()
            .ConfigureWorkarounds()
            .ConfigureEffects(e => { })
            .ConfigureMauiHandlers(handlers =>
            {
#if WINDOWS
                //handlers.AddHandler<CollectionView, Handlers.CollectionViewHandler>();
#endif

#if ANDROID
                //handlers.AddHandler<Slider, MaterialSliderHandler>();
                handlers.AddHandler<Slider, Berry.Maui.Handlers.Slider.BerrySliderHandler>();
#endif

                //handlers.AddHandler<Entry, MaterialEntryHandler>();
                //handlers.AddHandler<MaterialEntry, MaterialEntryHandler>();
                //handlers.AddHandler(typeof(Page), typeof(WorkaroundPageHandler));
            })
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");

                //fonts.AddFont("Sora-Bold.ttf", "SoraBold");
                //fonts.AddFont("Sora-Medium.ttf", "SoraMedium");
                //fonts.AddFont("Sora-Regular.ttf", "SoraRegular");
                //fonts.AddFont("Sora-SemiBold.ttf", "SoraSemiBold");
                //fonts.AddFont("Sora-Thin.ttf", "SoraThin");

                fonts.AddFont("Lato-Bold.ttf", "SoraBold");
                fonts.AddFont("Lato-Medium.ttf", "SoraMedium");
                fonts.AddFont("Lato-Regular.ttf", "SoraRegular");
                fonts.AddFont("Lato-SemiBold.ttf", "SoraSemiBold");
                fonts.AddFont("Lato-Thin.ttf", "SoraThin");

                fonts.AddFont("bloodcrow.ttf", "BloodCrow");

                //fonts.AddFont("MaterialIconsOutlined-Regular.otf", "Material");
                fonts.AddFont("MaterialIconsRound-Regular.otf", "Material");
                fonts.AddFont("fa-solid-900.ttf", "FaSolid");
            })
            .ConfigureLifecycleEvents(events =>
            {
#if WINDOWS
                events.AddWindows(
                    windows =>
                        windows.OnWindowCreated(window =>
                        {
                            window.ExtendsContentIntoTitleBar = false;

                            // Center WinUi window. Thanks to these links:
                            // https://stackoverflow.com/a/71730765
                            // https://learn.microsoft.com/en-us/answers/questions/1339421/centerscreen-in-windows-for-net-maui
                            var handle = WinRT.Interop.WindowNative.GetWindowHandle(window);
                            var id = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(handle);
                            var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(id);

                            if (appWindow is not null)
                            {
                                // Resize window
                                appWindow.Resize(new Windows.Graphics.SizeInt32(1150, 740));

                                var displayArea = Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(id, Microsoft.UI.Windowing.DisplayAreaFallback.Nearest);
                                if (displayArea is not null)
                                {
                                    var centeredPosition = appWindow.Position;
                                    centeredPosition.X = (displayArea.WorkArea.Width - appWindow.Size.Width) / 2;
                                    centeredPosition.Y = (displayArea.WorkArea.Height - appWindow.Size.Height) / 2;
                                    appWindow.Move(centeredPosition);
                                }
                            }
                        })
                );
#endif
            });

#if DEBUG
        builder.Logging.AddDebug();
#endif

        // Views
        builder.Services.AddTransient<HomeView>();
        builder.Services.AddTransient<SearchView>();
        builder.Services.AddTransient<MangaSearchView>();
        builder.Services.AddTransient<AnimeTabView>();
        builder.Services.AddTransient<EpisodePage>();
        builder.Services.AddTransient<MangaPage>();
        builder.Services.AddTransient<MangaReaderPage>();
        builder.Services.AddTransient<ProfileTabView>();
        builder.Services.AddTransient<ExtensionsView>();
        builder.Services.AddTransient<AnilistLoginView>();

        // ViewModels
        builder.Services.AddTransient<HomeViewModel>();
        builder.Services.AddTransient<SearchViewModel>();
        builder.Services.AddTransient<MangaSearchViewModel>();
        builder.Services.AddTransient<AnimeHomeViewModel>();
        builder.Services.AddTransient<EpisodeViewModel>();
        builder.Services.AddTransient<MangaHomeViewModel>();
        builder.Services.AddTransient<MangaItemViewModel>();
        builder.Services.AddTransient<MangaReaderViewModel>();
        builder.Services.AddTransient<ProfileViewModel>();
        builder.Services.AddTransient<ExtensionsViewModel>();

        // Services
        builder.Services.AddTransient(x => AniClientFactory());
        builder.Services.AddSingleton<IAlertService, AlertService>();
        builder.Services.AddScoped<SettingsService>();
        builder.Services.AddScoped<ProviderService>();

        return builder.Build();
    }

    public static AniClient AniClientFactory()
    {
        var settingsService = new SettingsService();
        settingsService.Load();

        if (string.IsNullOrWhiteSpace(settingsService.AnilistAccessToken))
            return new();

        var token = settingsService.AnilistAccessToken;
        var http = new HttpClient();
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        return new AniClient(http);
    }
}
