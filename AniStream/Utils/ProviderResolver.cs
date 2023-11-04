using System.Collections.Generic;
using Juro.Core.Providers;
using Juro.Providers.Anime;
using Juro.Providers.Anime.Indonesian;

namespace AniStream.Utils;

internal static class ProviderResolver
{
    public static IAnimeProvider GetAnimeProvider() => new Gogoanime();

    public static List<IAnimeProvider> GetAnimeProviders() =>
        new() { new Gogoanime(), new AnimePahe(), new Aniwave(), new Kaido(), new OtakuDesu() };
}
