using System.Net.Http;
using System.Net.Http.Headers;
using Anikin.Handlers;
using Anikin.Services;
using Anikin.Services.AlertDialog;
using Anikin.ViewModels;
using Anikin.Views;
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
using Sharpnado.Tabs;
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
            .UseSharpnadoTabs(loggerEnable: true, debugLogEnable: true)
            .ConfigureEffects(e => { })
            .ConfigureMauiHandlers(handlers =>
            {
#if WINDOWS
                //handlers.AddHandler<CollectionView, Handlers.CollectionViewHandler>();
#endif

                //handlers.AddHandler<Entry, MaterialEntryHandler>();
                handlers.AddHandler<MaterialEntry, MaterialEntryHandler>();
                handlers.AddHandler(typeof(Page), typeof(WorkaroundPageHandler));
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
            });

#if DEBUG
        builder.Logging.AddDebug();
#endif

        // Views
        builder.Services.AddTransient<HomeView>();
        builder.Services.AddTransient<AnimeTabView>();
        builder.Services.AddTransient<ProfileTabView>();
        builder.Services.AddTransient<SearchView>();
        builder.Services.AddTransient<ExtensionsView>();
        builder.Services.AddTransient<EpisodePage>();
        builder.Services.AddTransient<AnilistLoginView>();

        // ViewModels
        builder.Services.AddTransient<HomeViewModel>();
        builder.Services.AddTransient<ProfileViewModel>();
        builder.Services.AddTransient<SearchViewModel>();
        builder.Services.AddTransient<ExtensionsViewModel>();
        builder.Services.AddTransient<EpisodeViewModel>();

        // Services
        builder.Services.AddTransient<AniClient>(x => AniClientFactory());
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
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        return new AniClient(http);
    }
}
