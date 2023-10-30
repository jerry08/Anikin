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
        MainGrid.Margin = new Thickness(5, statusBarHeight + 10, 5, 0);
    }
}
