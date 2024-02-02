using System.Globalization;
using Juro.Core.Providers;

namespace Anikin.Utils.Extensions;

internal static class MangaProviderExtensions
{
    public static string GetLanguageDisplayName(this IMangaProvider provider)
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
