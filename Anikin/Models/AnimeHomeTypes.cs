using System.ComponentModel;

namespace Anikin.Models;

public enum AnimeHomeTypes
{
    [Description("Popular")]
    Popular,

    [Description("Recently Updated")]
    LastUpdated,

    [Description("Current Season")]
    CurrentSeason,

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
