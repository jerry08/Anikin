﻿using System.Collections.Generic;
using CommunityToolkit.Mvvm.ComponentModel;
using Juro.Core.Models.Anime;

namespace Anikin.Models;

public partial class EpisodeRange : ObservableObject
{
    public string Name { get; set; } = default!;

    public List<Episode> Episodes { get; set; } = [];

    [ObservableProperty]
    private bool _isSelected;

    public EpisodeRange(IEnumerable<Episode> episodes, int startIndex, int endIndex)
    {
        Episodes.AddRange(episodes);
        Name = $"{startIndex} - {endIndex}";
    }

    public override string ToString() => Name;
}
