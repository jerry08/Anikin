using HtmlAgilityPack;

namespace Anikin.Utils;

internal static class Html
{
    public static HtmlDocument Parse(string source)
    {
        var document = new HtmlDocument();
        document.LoadHtml(HtmlEntity.DeEntitize(source));
        return document;
    }

    public static string? ConvertToPlainText(string? value) =>
        string.IsNullOrWhiteSpace(value) ? value : Parse(value).DocumentNode.InnerText;
}
