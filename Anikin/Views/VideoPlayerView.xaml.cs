using System;
using System.Threading.Tasks;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Platform;

namespace Anikin.Views;

public partial class VideoPlayerView
{
    public VideoPlayerView()
    {
        InitializeComponent();

#if WINDOWS
        videoPlayer.Loaded += async (_, _) =>
        {
            ArgumentNullException.ThrowIfNull(videoPlayer.Handler?.MauiContext);

            var grid = (Microsoft.UI.Xaml.Controls.Grid)
                videoPlayer.ToPlatform(videoPlayer.Handler.MauiContext);
            var buttonContainer = grid.Children[1];

            var lastVisibility = buttonContainer.Visibility;
            while (true)
            {
                if (!IsLoaded)
                    break;

                if (lastVisibility != buttonContainer.Visibility)
                {
                    lastVisibility = buttonContainer.Visibility;

                    if (buttonContainer.Visibility is Microsoft.UI.Xaml.Visibility.Visible)
                    {
                        await subtitlesContainer.TranslateTo(0, -80, 450);
                    }
                    else
                    {
                        await subtitlesContainer.TranslateTo(0, 0, 450);
                    }
                }

                await Task.Delay(400);
            }
        };
#endif
    }

    // Make anything fullscreen
    // https://github.com/CommunityToolkit/Maui/issues/113#issuecomment-1383065837
    // https://github.com/davidbritch/dotnet-maui-videoplayer/issues/9#issuecomment-1323488802
    protected override void OnSizeAllocated(double width, double height)
    {
        //Dispatcher.StartTimer(TimeSpan.FromMilliseconds(1), () =>
        //{
        //    videoPlayer.WidthRequest = width;
        //    videoPlayer.HeightRequest = height;
        //
        //    return false;
        //});
        base.OnSizeAllocated(width, height);
    }
}
