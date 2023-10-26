using Juro.Core.Providers;
using Juro.Providers.Anime;

namespace AniStream.Utils;

internal static class ProviderResolver
{
    public static IAnimeProvider GetAnimeProvider() => new Gogoanime();
}
