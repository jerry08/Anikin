using System;
using System.Text.Json.Serialization;
using Juro.Core.Models.Videos;
using SQLite;

namespace Anikin.ViewModels.Components;

public class DownloadItem
{
    public int Id { get; set; }

    public string Key { get; set; } = default!;

    [Ignore, JsonIgnore]
    public object? Entity { get; set; }

    public SourceType SourceType { get; set; }

    public DateTime DownloadDate { get; set; }

    public string? Title { get; set; }

    public string? ImageUrl { get; set; }

    public DownloadStatus Status { get; set; }

    public string? ErrorMessage { get; set; }

    public static DownloadItem From(VideoSource video, string title) =>
        new()
        {
            Key = video.VideoUrl,
            Entity = video,
            SourceType = SourceType.Anime,
            Title = title,
            //ImageUrl = viewModel.Video?.Thumbnails.TryGetWithHighestResolution()?.Url,
        };
}
