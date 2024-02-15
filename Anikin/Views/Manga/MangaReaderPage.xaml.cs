using System.Timers;
using Android.Widget;
using Anikin.ViewModels.Manga;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Layouts;

namespace Anikin.Views.Manga;

public partial class MangaReaderPage
{
    private Timer Timer = new();

    public MangaReaderPage(MangaReaderViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        var tapGesture = new TapGestureRecognizer();
        tapGesture.Tapped += OnTapped;
        MainContent.GestureRecognizers.Add(tapGesture);

        slider.DragStarted += (s, e) =>
        {
            StopInteraction();
        };

        slider.DragCompleted += (s, e) =>
        {
            StartInteraction();
        };

        //SizeChanged += (s, e) =>
        //{
        //    var totalHeight1 = PagesScrollView.Height;
        //    var totalHeight2 = PagesScrollView.Measure(
        //        Window.Width - Padding.HorizontalThickness,
        //        Window.Height
        //    );
        //    var totalHeight3 = PagesScrollView.DesiredSize;
        //    var totalHeight4 = PagesScrollView.ComputeDesiredSize(
        //        double.PositiveInfinity,
        //        double.PositiveInfinity
        //    );
        //    var totalHeight5 = PagesScrollView.Measure(
        //        double.PositiveInfinity,
        //        double.PositiveInfinity
        //    );
        //
        //    var totalHeight6 = PagesScrollView
        //        .ComputeDesiredSize(double.PositiveInfinity, double.PositiveInfinity)
        //        .Height;
        //
        //    //Toast.Make($"{totalHeight6}").Show();
        //
        //    slider.Maximum = totalHeight6;
        //};

        //slider.HandlerChanged += (s, e) =>
        //{
        //    if (slider.Handler?.PlatformView is SeekBar seekBar)
        //    {
        //        seekBar.IncrementProgressBy(1);
        //    }
        //};

        SliderView.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName is nameof(IsVisible))
            {
                if (!SliderView.IsVisible)
                    return;

                StartInteraction();
            }
        };
    }

    void StartInteraction()
    {
        Timer.Enabled = false;
        Timer.Stop();

        Timer = new()
        {
            AutoReset = false,
            Enabled = true,
            Interval = 5000
        };

        Timer.Elapsed += (_, _) =>
        {
            Timer.Stop();
            Timer.Enabled = false;

            HideControls();
        };

        Timer.Start();
    }

    void StopInteraction()
    {
        Timer.Enabled = false;
        Timer.Stop();
    }

    private void OnTapped(object? sender, TappedEventArgs e)
    {
        if (!SliderView.IsVisible)
        {
            ShowControls();
        }
        else
        {
            HideControls();
        }
    }

    void ShowControls()
    {
        MainThread.BeginInvokeOnMainThread(() =>
        {
            if (!SliderView.IsVisible)
            {
                SliderView.IsVisible = true;
                SliderView.ScaleTo(1, 80);

                TitleGrid.IsVisible = true;
                TitleGrid.ScaleTo(1, 80);
            }
        });
    }

    void HideControls()
    {
        MainThread.BeginInvokeOnMainThread(async () =>
        {
            if (SliderView.IsVisible)
            {
                await SliderView.ScaleTo(0, 80);
                SliderView.IsVisible = false;
            }
        });

        MainThread.BeginInvokeOnMainThread(async () =>
        {
            if (TitleGrid.IsVisible)
            {
                await TitleGrid.ScaleTo(0, 80);
                TitleGrid.IsVisible = false;
            }
        });
    }

    private void PagesScrollView_Scrolled(object? sender, ScrolledEventArgs e)
    {
        if (!IsValueChangedFromSlider)
        {
            HideControls();
        }
    }

    //private void Slider_ValueChanged(object sender, ValueChangedEventArgs e)
    //{
    //    //var totalHeight1 = PagesScrollView.Height;
    //    //var totalHeight2 = PagesScrollView.Measure(
    //    //    Window.Width - Padding.HorizontalThickness,
    //    //    Window.Height
    //    //);
    //    //var totalHeight3 = PagesScrollView.DesiredSize;
    //    //var totalHeight4 = PagesScrollView.ComputeDesiredSize(
    //    //    double.PositiveInfinity,
    //    //    double.PositiveInfinity
    //    //);
    //    //var totalHeight5 = PagesScrollView.Measure(
    //    //    double.PositiveInfinity,
    //    //    double.PositiveInfinity
    //    //);
    //
    //    var totalHeight6 = PagesScrollView
    //        .ComputeDesiredSize(double.PositiveInfinity, double.PositiveInfinity)
    //        .Height;
    //
    //    //totalHeight6 /= DeviceDisplay.MainDisplayInfo.Density;
    //
    //    //var val = (int)e.NewValue * 10;
    //    var val = e.NewValue * (totalHeight6 / slider.Maximum);
    //
    //    if (e.NewValue == slider.Minimum)
    //    {
    //        PagesScrollView.ScrollToAsync(PagesScrollView.X, val, false);
    //    }
    //    else if (e.NewValue == slider.Maximum)
    //    {
    //        PagesScrollView.ScrollToAsync(PagesScrollView.X, val, false);
    //    }
    //    else
    //    {
    //        PagesScrollView.ScrollToAsync(PagesScrollView.X, val, false);
    //    }
    //}

    public bool IsValueChangedFromSlider { get; set; }

    private async void Slider_ValueChanged(object? sender, ValueChangedEventArgs e)
    {
        IsValueChangedFromSlider = true;

        var totalHeight = PagesScrollView
            .ComputeDesiredSize(double.PositiveInfinity, double.PositiveInfinity)
            .Height;

        var val = (e.NewValue - 1) * (totalHeight / slider.Maximum);

        await PagesScrollView.ScrollToAsync(PagesScrollView.X, val, false);

        IsValueChangedFromSlider = false;
    }

    //private void Slider_ValueChanged(object sender, ValueChangedEventArgs e)
    //{
    //    PagesScrollView2.ScrollTo((int)e.NewValue);
    //}
}
