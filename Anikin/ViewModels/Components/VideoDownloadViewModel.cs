using Juro.Core.Models.Anime;

namespace Anikin.ViewModels.Components;

public partial class VideoDownloadViewModel : DownloadViewModelBase
{
    public string? Key => Anime?.Id;

    public IAnimeInfo? Anime { get; set; }
}
