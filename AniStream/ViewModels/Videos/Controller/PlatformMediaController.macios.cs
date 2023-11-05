using System;
using Berry.Maui.Core;
using Juro.Core.Models.Videos;

namespace AniStream.ViewModels;

internal class PlatformMediaController : IDisposable
{
    public PlatformMediaController(VideoPlayerViewModel playerViewModel, VideoServer videoServer)
    { }

    public void OnLoaded(IMediaElement mediaElement) { }

    public void Initialize() { }

    public void UpdateSourceInfo() { }

    public void Dispose() { }
}
