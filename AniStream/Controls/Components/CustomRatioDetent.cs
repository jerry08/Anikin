using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;
using The49.Maui.BottomSheet;

namespace AniStream.Controls;

[ContentProperty("Ratio")]
public class CustomRatioDetent : Detent
{
    public static readonly BindableProperty RatioProperty = BindableProperty.Create(
        nameof(Ratio),
        typeof(float),
        typeof(RatioDetent),
        0f
    );

    public float Ratio
    {
        get { return (float)GetValue(RatioProperty); }
        set { SetValue(RatioProperty, value); }
    }

    public override double GetHeight(BottomSheet page, double maxSheetHeight)
    {
        if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        {
            return maxSheetHeight * Ratio;
        }
        else
        {
            return maxSheetHeight;
        }
    }
}
