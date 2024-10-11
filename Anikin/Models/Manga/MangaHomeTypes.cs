using System.ComponentModel;

namespace Anikin.Models.Manga;

public enum MangaHomeTypes
{
    [Description("Popular")]
    Popular,

    [Description("Recently Updated")]
    LastUpdated,

    [Description("Trending")]
    Trending,

    [Description("New Season")]
    NewSeason,

    [Description("Feminine Audience")]
    FeminineMedia,

    [Description("Male Audience")]
    MaleMedia,

    [Description("Trash Anime")]
    TrashMedia,
}
