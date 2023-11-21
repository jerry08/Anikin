using System;
using System.Collections.Generic;
using System.Linq;
using Anikin.Services;
using Juro.Clients;
using Juro.Core.Providers;

namespace Anikin.Utils;

internal static class ProviderResolver
{
    public static IAnimeProvider GetAnimeProvider()
    {
        var settingsService = new SettingsService();
        settingsService.Load();

        var providers = GetAnimeProviders();

        if (string.IsNullOrWhiteSpace(settingsService.LastProviderKey))
            return providers[0];

        return providers.Find(x => x.Key == settingsService.LastProviderKey) ?? providers[0];
    }

    public static List<IAnimeProvider> GetAnimeProviders()
    {
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
#if DEBUG
            App.AlertService.ShowAlert(
                "Error",
                $"-- This message is shown only in debug mode --{Environment.NewLine}{ex}"
            );
#endif
            return new();
        }
    }
}
