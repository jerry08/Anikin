using System.Globalization;
using Juro.Core.Providers;

namespace Anikin.Utils.Extensions;

internal static class AnimeProviderExtensions
{
    public static string GetLanguageDisplayName(this IAnimeProvider provider)
    {
        try
        {
            var culture = new CultureInfo(provider.Language);
            return culture.NativeName;
        }
        catch
        {
            return string.Empty;
        }
    }
}
