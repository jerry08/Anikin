using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Platform;
#if WINDOWS
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
#endif

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
            var platformView = videoPlayer.ToPlatform(videoPlayer.Handler.MauiContext);

            if (
                FindChild<Microsoft.UI.Xaml.Controls.MediaPlayerElement>(platformView)
                is not { } nativePlayer
            )
            {
                return;
            }

            var transportControls = nativePlayer.TransportControls;

            transportControls.Loaded += TransportControlsLoaded;

            if (transportControls.IsLoaded)
            {
                TransportControlsLoaded(transportControls, null!);
            }

            void TransportControlsLoaded(object sender, RoutedEventArgs e)
            {
                transportControls.Loaded -= TransportControlsLoaded;

                if (
                    FindChild<Microsoft.UI.Xaml.Controls.Grid>(
                        transportControls,
                        "ControlPanelGrid"
                    )?.Parent
                    is not FrameworkElement controlPanel
                )
                {
                    return;
                }

                var isVisible = controlPanel.Opacity > 0.5;

                var token = controlPanel.RegisterPropertyChangedCallback(
                    UIElement.OpacityProperty,
                    async (_, _) =>
                    {
                        var nowVisible = controlPanel.Opacity > 0.5;
                        if (isVisible == nowVisible)
                            return;

                        isVisible = nowVisible;
                        await subtitlesContainer.TranslateToAsync(0, isVisible ? -80 : 0, 450);
                    }
                );

                videoPlayer.Unloaded += Cleanup;

                void Cleanup(object? s, EventArgs e)
                {
                    videoPlayer.Unloaded -= Cleanup;
                    controlPanel.UnregisterPropertyChangedCallback(
                        UIElement.OpacityProperty,
                        token
                    );
                }
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

#if WINDOWS
    public static T? FindChild<T>(DependencyObject parent)
        where T : DependencyObject
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
        {
            var child = VisualTreeHelper.GetChild(parent, i);
            if (child is T found)
                return found;

            var result = FindChild<T>(child);
            if (result != null)
                return result;
        }

        return null;
    }

    // Helper overload to find by name
    public static T? FindChild<T>(DependencyObject parent, string name)
        where T : FrameworkElement
    {
        var childCount = VisualTreeHelper.GetChildrenCount(parent);

        for (var i = 0; i < childCount; i++)
        {
            var child = VisualTreeHelper.GetChild(parent, i);

            if (child is T typedChild && typedChild.Name == name)
            {
                return typedChild;
            }

            if (FindChild<T>(child, name) is { } result)
            {
                return result;
            }
        }

        return null;
    }
#endif
}
