using System.Collections.Generic;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using CommunityToolkit.Mvvm.ComponentModel;
using Jita.AniList.Models;

namespace Anikin.Models;

public partial class AnimeHomeRange : ObservableObject
{
    public string Name { get; set; }

    [ObservableProperty]
    bool _isLoading;

    public AnimeHomeTypes Type { get; set; }

    public ObservableRangeCollection<Media> Medias { get; set; } = [];

    [ObservableProperty]
    private bool _isSelected;

    public AnimeHomeRange(AnimeHomeTypes type)
    {
        Type = type;
        Name = Type.GetBestDisplayName();
    }

    public AnimeHomeRange(AnimeHomeTypes type, IEnumerable<Media> medias) : this(type)
    {
        Medias.AddRange(medias);
    }

    public override string ToString() => Name;
}
