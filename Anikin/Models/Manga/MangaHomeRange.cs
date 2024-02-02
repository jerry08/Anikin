using System.Collections.Generic;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using CommunityToolkit.Mvvm.ComponentModel;
using Jita.AniList.Models;

namespace Anikin.Models.Manga;

public partial class MangaHomeRange : ObservableObject
{
    public string Name { get; set; }

    [ObservableProperty]
    bool _isLoading;

    public MangaHomeTypes Type { get; set; }

    public ObservableRangeCollection<Media> Medias { get; set; } = [];

    [ObservableProperty]
    private bool _isSelected;

    public MangaHomeRange(MangaHomeTypes type)
    {
        Type = type;
        Name = Type.GetBestDisplayName();
    }

    public MangaHomeRange(MangaHomeTypes type, IEnumerable<Media> medias)
        : this(type)
    {
        Medias.AddRange(medias);
    }

    public override string ToString() => Name;
}
