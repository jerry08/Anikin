using Microsoft.Maui;
using Microsoft.Maui.Handlers;
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

public partial class BerrySliderHandler : IBerrySliderHandler
{
    public static IPropertyMapper<ISlider, IBerrySliderHandler> Mapper = new PropertyMapper<
        ISlider,
        IBerrySliderHandler
    >(ViewHandler.ViewMapper)
    {
        [nameof(ISlider.Maximum)] = MapMaximum,
        [nameof(ISlider.MaximumTrackColor)] = MapMaximumTrackColor,
        [nameof(ISlider.Minimum)] = MapMinimum,
        [nameof(ISlider.MinimumTrackColor)] = MapMinimumTrackColor,
        [nameof(ISlider.ThumbColor)] = MapThumbColor,
        [nameof(ISlider.ThumbImageSource)] = MapThumbImageSource,
        [nameof(ISlider.Value)] = MapValue,
    };

    public static CommandMapper<ISlider, IBerrySliderHandler> CommandMapper =
        new(ViewCommandMapper) { };

    public BerrySliderHandler()
        : base(Mapper, CommandMapper) { }

    public BerrySliderHandler(IPropertyMapper? mapper)
        : base(mapper ?? Mapper, CommandMapper) { }

    public BerrySliderHandler(IPropertyMapper? mapper, CommandMapper? commandMapper)
        : base(mapper ?? Mapper, commandMapper ?? CommandMapper) { }

    ISlider IBerrySliderHandler.VirtualView => VirtualView;

    PlatformView IBerrySliderHandler.PlatformView => PlatformView;
}
