using System.Collections.Generic;
using CommunityToolkit.Mvvm.ComponentModel;
using Juro.Core.Models.Manga;

namespace Anikin.Models.Manga;

public partial class MangaChapterRange : ObservableObject
{
    public string Name { get; set; } = default!;

    public List<IMangaChapter> Chapters { get; set; } = [];

    [ObservableProperty]
    private bool _isSelected;

    public MangaChapterRange(IEnumerable<IMangaChapter> episodes, int startIndex, int endIndex)
    {
        Chapters.AddRange(episodes);
        Name = $"{startIndex} - {endIndex}";
    }

    public override string ToString() => Name;
}
