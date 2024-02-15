using Microsoft.Maui;
#if __IOS__ || MACCATALYST
using PlatformView = UIKit.UISlider;
#elif ANDROID
using PlatformView = Google.Android.Material.Slider.Slider;
#elif WINDOWS
using PlatformView = Microsoft.UI.Xaml.Controls.Slider;
#elif TIZEN
using PlatformView = Tizen.NUI.Components.Slider;
#elif (NETSTANDARD || !PLATFORM) || (NET6_0_OR_GREATER && !IOS && !ANDROID && !TIZEN)
using PlatformView = System.Object;
#endif

namespace Berry.Maui.Handlers.Slider;

public partial interface IBerrySliderHandler : IViewHandler
{
    new ISlider VirtualView { get; }
    new PlatformView PlatformView { get; }
}
