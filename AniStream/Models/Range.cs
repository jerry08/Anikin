using System.Collections.Generic;
using CommunityToolkit.Mvvm.ComponentModel;
using Juro.Core.Models.Anime;

namespace AniStream.Models;

public partial class Range : ObservableObject
{
    public string Name { get; set; } = default!;

    public List<Episode> Episodes { get; set; } = new();

    [ObservableProperty]
    private bool _isSelected;

    public Range(IEnumerable<Episode> episodes, int startIndex, int endIndex)
    {
        Episodes.AddRange(episodes);
        Name = $"{startIndex} - {endIndex}";
    }

    public override string ToString() => Name;
}
