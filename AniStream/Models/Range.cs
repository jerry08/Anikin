using System.Collections.Generic;
using Juro.Core.Models.Anime;

namespace AniStream.Models;

public class Range
{
    public string Name { get; set; } = default!;

    public List<Episode> Episodes { get; set; } = new();

    public Range(IEnumerable<Episode> episodes, int startIndex, int endIndex)
    {
        Episodes.AddRange(episodes);
        Name = $"{startIndex} - {endIndex}";
    }

    public override string ToString() => Name;
}
