using System;
using System.Collections.Generic;
using System.Linq;
using Anikin.Services;
using Juro.Clients;
using Juro.Core.Providers;
using Juro.Providers.Anime;
using Juro.Providers.Anime.Indonesian;

namespace Anikin.Utils;

internal static class ProviderResolver
{
    public static IAnimeProvider? GetAnimeProvider()
    {
        var settingsService = new SettingsService();
        settingsService.Load();

        var providers = GetAnimeProviders();

        if (providers.Count == 0)
            return null;

        if (string.IsNullOrWhiteSpace(settingsService.LastProviderKey))
            return providers.FirstOrDefault();

        return providers.Find(x => x.Key == settingsService.LastProviderKey)
            ?? providers.FirstOrDefault();
    }

    public static List<IAnimeProvider> GetAnimeProviders()
    {
        return
        [
            new Gogoanime(),
            new AnimePahe(),
            new Aniwatch(),
            new Aniwave(),
            new Kaido(),
            new OtakuDesu()
        ];

        try
        {
            var client = new AnimeClient();
            var providers = client.GetAllProviders();

            return providers
                .OrderByDescending(x => x.Name.Contains("gogo", StringComparison.OrdinalIgnoreCase))
                .ThenBy(x => x.Name)
                .ToList();
        }
        catch (Exception ex)
        {
            if (App.IsInDeveloperMode)
            {
                App.AlertService.ShowAlert("Error", $"{ex}");
            }

            return [];
        }
    }
}
