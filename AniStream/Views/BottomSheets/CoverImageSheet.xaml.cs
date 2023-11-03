using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Devices;

namespace AniStream.Views.BottomSheets;

public partial class CoverImageSheet
{
    public CoverImageSheet()
    {
        InitializeComponent();

        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;

        //var navigationBarHeight = (int)(
        //    ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density
        //);

        var marginBottom = 0.0;
        //if (navigationBarHeight > 0)
        //    marginBottom += navigationBarHeight;

        var marginTop = 10.0;
        if (statusBarHeight > 0)
            marginTop += statusBarHeight;

        MainGrid.Margin = new Thickness(5, marginTop, 5, marginBottom);

        //imag.SizeChanged += (s, e) =>
        //{
        //
        //};
        //
        //imag.Loaded += async (s, e) =>
        //{
        //    //var gg = await imag.Source.GetPlatformImageAsync(imag.Handler.MauiContext);
        //    //gg.Value.IntrinsicHeight;
        //
        //    imag.Source.LoadImage(imag.Handler.MauiContext, (d) =>
        //    {
        //        var h2 = imag.HeightRequest;
        //        var h3 = imag.WidthRequest;
        //    });
        //
        //    var hh = this.Detents[0].GetHeight(this, 800);
        //    var h1 = imag.Height;
        //};
    }
}
