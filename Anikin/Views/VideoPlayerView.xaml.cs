namespace Anikin.Views;

public partial class VideoPlayerView
{
    public VideoPlayerView()
    {
        InitializeComponent();
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
