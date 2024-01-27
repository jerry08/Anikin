using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Devices;

namespace Anikin.Views.BottomSheets;

public partial class AppUpdateSheet
{
    public AppUpdateSheet()
    {
        InitializeComponent();

        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;

        var marginBottom = 0.0;
        var marginTop = 10.0;
        if (statusBarHeight > 0)
            marginTop += statusBarHeight;

        MainGrid.Margin = new Thickness(5, marginTop, 5, marginBottom);
    }
}
