using System;
using Berry.Maui.Core;

namespace Anikin.ViewModels;

internal class PlatformMediaController : IDisposable
{
    private readonly VideoPlayerViewModel _playerViewModel;

    private IMediaElement? MediaElement { get; set; }

    public PlatformMediaController(VideoPlayerViewModel playerViewModel)
    {
        _playerViewModel = playerViewModel;
    }

    public void OnLoaded(IMediaElement mediaElement)
    {
        MediaElement = mediaElement;
    }

    public void Initialize() { }

    public void UpdateSourceInfo() { }

    public void Dispose()
    {
        _playerViewModel.UpdateProgress();
        MediaElement?.Stop();
    }
}
