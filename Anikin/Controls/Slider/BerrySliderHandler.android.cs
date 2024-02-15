using System.Linq;
using Android.Content.Res;
using Android.Widget;
using Anikin.Controls.Slider;
using Berry.Maui.Controls;
using Google.Android.Material.Slider;
using Java.Lang;
using Microsoft.Maui;
using Microsoft.Maui.Graphics;
using Microsoft.Maui.Handlers;
using Microsoft.Maui.Platform;
using MSlider = Google.Android.Material.Slider.Slider;

namespace Berry.Maui.Handlers.Slider;

public partial class BerrySliderHandler : ViewHandler<ISlider, MSlider>
{
    SeekBarChangeListener ChangeListener { get; } = new();

    protected override MSlider CreatePlatformView()
    {
        return new MSlider(Context)
        {
            DuplicateParentStateEnabled = false,
            StepSize = 1,
            TickVisible = false,
            ValueFrom = 0,
            ValueTo = 100
        };
    }

    protected override void ConnectHandler(MSlider platformView)
    {
        ChangeListener.Handler = this;

        //platformView.SetOnChangeListener(ChangeListener);
        var method = Class
            .ForName("com.google.android.material.slider.BaseSlider")
            .GetDeclaredMethods()
            //.FirstOrDefault(x => x.Name == "addOnChangeListener");
            .FirstOrDefault(x => x.Name == "addOnChangeListener");
        method?.Invoke(platformView, ChangeListener); // this is implementing IBaseOnChangeListener

        Class
            .ForName("com.google.android.material.slider.BaseSlider")
            .GetDeclaredMethods()
            .FirstOrDefault(x => x.Name == "addOnSliderTouchListener")
            ?.Invoke(platformView, ChangeListener);
    }

    protected override void DisconnectHandler(MSlider platformView)
    {
        ChangeListener.Handler = null;
        //platformView.SetOnTouchListener(null);
        // https://github.com/xamarin/AndroidX/issues/230
        var method = Class
            .ForName("com.google.android.material.slider.BaseSlider")
            .GetDeclaredMethods()
            .FirstOrDefault(x => x.Name == "removeOnChangeListener");
        method?.Invoke(platformView, ChangeListener);
    }

    public static void MapMinimum(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateMinimum(slider);
    }

    public static void MapMaximum(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateMaximum(slider);
    }

    public static void MapValue(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateValue(slider);
    }

    public static void MapMinimumTrackColor(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateMinimumTrackColor(slider);
    }

    public static void MapMaximumTrackColor(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateMaximumTrackColor(slider);
    }

    public static void MapThumbColor(IBerrySliderHandler handler, ISlider slider)
    {
        handler.PlatformView?.UpdateThumbColor(slider);
    }

    public static void MapThumbImageSource(IBerrySliderHandler handler, ISlider slider)
    {
        var provider = handler.GetRequiredService<IImageSourceServiceProvider>();

        handler.PlatformView?.UpdateThumbImageSourceAsync(slider, provider).FireAndForget(handler);
    }

    void OnProgressChanged(MSlider seekBar, float progress, bool fromUser)
    {
        if (VirtualView == null || !fromUser)
            return;

        var min = VirtualView.Minimum;
        var max = VirtualView.Maximum;

        //var value = min + (max - min) * (progress / SliderExtensions.PlatformMaxValue);
        var value = progress;

        VirtualView.Value = value;
    }

    void OnStartTrackingTouch(MSlider seekBar) => VirtualView?.DragStarted();

    void OnStopTrackingTouch(MSlider seekBar) => VirtualView?.DragCompleted();

    internal class SeekBarChangeListener
        : Java.Lang.Object,
            //MSlider.IOnSliderTouchListener,
            //MSlider.IOnChangeListener
            IBaseOnChangeListener,
            IBaseOnSliderTouchListener
    {
        public BerrySliderHandler? Handler { get; set; }

        public SeekBarChangeListener() { }

        //public void OnProgressChanged(MSlider? seekBar, int progress, bool fromUser)
        //{
        //    if (Handler == null || seekBar == null)
        //        return;
        //
        //    Handler.OnProgressChanged(seekBar, progress, fromUser);
        //}

        //public void OnStartTrackingTouch(MSlider? seekBar)
        //{
        //    if (Handler == null || seekBar == null)
        //        return;
        //
        //    Handler.OnStartTrackingTouch(seekBar);
        //}
        //
        //public void OnStopTrackingTouch(MSlider? seekBar)
        //{
        //    if (Handler == null || seekBar == null)
        //        return;
        //
        //    Handler.OnStopTrackingTouch(seekBar);
        //}
        //
        ////public void OnStartTrackingTouch(Object p0) { }
        //
        //public void OnStopTrackingTouch(Object p0) { }

        //public void OnValueChange(MSlider seekBar, float progress, bool fromUser)
        public void OnValueChange(Object? seekBar, float progress, bool fromUser)
        {
            if (Handler == null || seekBar == null)
                return;

            Handler.OnProgressChanged((MSlider)seekBar, progress, fromUser);
        }

        public void OnStartTrackingTouch(Object? slider)
        {
            if (Handler == null || slider == null)
                return;

            Handler.OnStartTrackingTouch((MSlider)slider);
        }

        public void OnStopTrackingTouch(Object slider)
        {
            if (Handler == null || slider == null)
                return;

            Handler.OnStopTrackingTouch((MSlider)slider);
        }

        //public void OnValueChange(Object p0, float p1, bool p2) { }
    }
}
