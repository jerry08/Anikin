using System.Threading.Tasks;
using Android.Content.Res;
using Android.Graphics;
using Berry.Maui.Extensions;
using Microsoft.Maui;
using Microsoft.Maui.Platform;
using MSlider = Google.Android.Material.Slider.Slider;

namespace Berry.Maui.Handlers.Slider;

public static class SliderExtensions
{
    public const double PlatformMaxValue = int.MaxValue;

    public static void UpdateMinimum(this MSlider mSlider, ISlider slider) =>
        UpdateValue(mSlider, slider);

    public static void UpdateMaximum(this MSlider mSlider, ISlider slider) =>
        UpdateValue(mSlider, slider);

    public static void UpdateValue(this MSlider mSlider, ISlider slider)
    {
        var min = slider.Minimum;
        var max = slider.Maximum;
        var value = slider.Value;

        //mSlider.Value = (int)((value - min) / (max - min) * PlatformMaxValue);
        mSlider.Value = (int)value;
        mSlider.ValueFrom = (float)min;
        mSlider.ValueTo = (float)max;
    }

    public static void UpdateMinimumTrackColor(this MSlider mSlider, ISlider slider)
    {
        if (slider.MinimumTrackColor != null)
        {
            //mSlider.TrackTintList = ColorStateList.ValueOf(slider.MinimumTrackColor.ToPlatform());
            mSlider.TrackActiveTintList = ColorStateList.ValueOf(
                slider.MinimumTrackColor.ToPlatform()
            );
            //mSlider.TrackTintMode = PorterDuff.Mode.SrcIn;
        }
    }

    public static void UpdateMaximumTrackColor(this MSlider mSlider, ISlider slider)
    {
        if (slider.MaximumTrackColor != null)
        {
            //mSlider.BackgroundTintList = ColorStateList.ValueOf(
            //    slider.MaximumTrackColor.ToPlatform()
            //);
            //mSlider.BackgroundTintMode = PorterDuff.Mode.SrcIn;

            mSlider.TrackInactiveTintList = ColorStateList.ValueOf(
                slider.MaximumTrackColor.ToPlatform()
            );
        }
    }

    public static void UpdateThumbColor(this MSlider mSlider, ISlider slider)
    {
        mSlider.ThumbTintList = ColorStateList.ValueOf(slider.ThumbColor.ToPlatform());
        mSlider.HaloTintList = ColorStateList.ValueOf(slider.ThumbColor.ToPlatform());
    }

    public static async Task UpdateThumbImageSourceAsync(
        this MSlider mSlider,
        ISlider slider,
        IImageSourceServiceProvider provider
    )
    {
        var context = mSlider.Context;

        if (context == null)
            return;

        var thumbImageSource = slider.ThumbImageSource;

        if (thumbImageSource != null)
        {
            var service = provider.GetRequiredImageSourceService(thumbImageSource);
            var result = await service.GetDrawableAsync(thumbImageSource, context);

            var thumbDrawable = result?.Value;

            //if (mSlider.IsAlive() && thumbDrawable != null)
            //    mSlider.SetThumb(thumbDrawable);
        }
    }
}
