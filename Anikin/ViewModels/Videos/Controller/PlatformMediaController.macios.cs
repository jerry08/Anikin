using System;
using Berry.Maui.Core;

namespace Anikin.ViewModels;

internal class PlatformMediaController(VideoPlayerViewModel playerViewModel) : IDisposable
{
    private readonly VideoPlayerViewModel _playerViewModel = playerViewModel;

    private IMediaElement? MediaElement { get; set; }

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
