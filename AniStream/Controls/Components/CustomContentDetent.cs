using Berry.Maui;
using Microsoft.Maui.Devices;
using The49.Maui.BottomSheet;

namespace AniStream.Controls;

public class CustomContentDetent : ContentDetent
{
    public override double GetHeight(BottomSheet page, double maxSheetHeight)
    {
        return base.GetHeight(page, maxSheetHeight)
            - (ApplicationEx.GetStatusBarHeight() / DeviceDisplay.Current.MainDisplayInfo.Density);
    }
}
