using System.Collections.Generic;
using AniStream.Services;
using Juro.Core.Providers;
using Juro.Providers.Anime;
using Juro.Providers.Anime.Indonesian;

namespace AniStream.Utils;

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

    public static List<IAnimeProvider> GetAnimeProviders() =>
        new() { new Gogoanime(), new AnimePahe(), new Aniwave(), new Kaido(), new OtakuDesu() };
}
