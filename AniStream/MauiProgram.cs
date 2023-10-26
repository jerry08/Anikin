using System.Net.Http;
using System.Net.Http.Headers;
using AniStream.Services;
using AniStream.Services.AlertDialog;
using AniStream.Utils;
using AniStream.ViewModels;
using AniStream.Views;
using Berry.Maui;
using CommunityToolkit.Maui;
using Jita.AniList;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using Microsoft.Maui.LifecycleEvents;
using Sharpnado.Tabs;
using The49.Maui.BottomSheet;
using Woka;

namespace AniStream;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .UseBerryMediaElement()
            .ConfigureWorkarounds()
            .UseBerry()
            .UseBottomSheet()
            .UseInsets()
            .UseSharpnadoTabs(loggerEnable: true, debugLogEnable: true)
            .ConfigureEffects(e =>
            {
            })
            .ConfigureMauiHandlers(handlers =>
            {
#if WINDOWS
                //handlers.AddHandler<CollectionView, Handlers.CollectionViewHandler>();
#endif
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
#if ANDROID
                events.AddAndroid(android => android
                    .OnCreate((activity, bundle) =>
                    {
                        var manager = new StatusBarStyleManager();
                        manager.SetDefault();
                    })
                );
#elif IOS
                events.AddiOS(ios => ios
                    .OnActivated((app) =>
                    {
                        var manager = new StatusBarStyleManager();
                        manager.SetDefault();
                    }));
#endif
            });

#if DEBUG
        builder.Logging.AddDebug();
#endif

        // Views
        builder.Services.AddTransient<HomeView>();
        builder.Services.AddTransient<AnimeTabView>();
        builder.Services.AddTransient<ProfileTabView>();
        builder.Services.AddTransient<SearchView>();
        builder.Services.AddTransient<EpisodePage>();

        // ViewModels
        builder.Services.AddTransient<HomeViewModel>();
        builder.Services.AddTransient<ProfileViewModel>();
        builder.Services.AddTransient<SearchViewModel>();
        builder.Services.AddTransient<EpisodeViewModel>();

        // Services
        builder.Services.AddSingleton<AniClient>(x => AniClientFactory());
        builder.Services.AddSingleton<IAlertService, AlertService>();
        builder.Services.AddScoped<PreferenceService>();

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
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            token
        );

        return new AniClient(http);
    }
}