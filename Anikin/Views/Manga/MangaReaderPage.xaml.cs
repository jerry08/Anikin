using System;
using System.Timers;
using Anikin.ViewModels.Manga;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Layouts;

namespace Anikin.Views.Manga;

public partial class MangaReaderPage
{
    private Timer Timer = new();

    public bool IsManuallyScrolling { get; private set; }

    public int FirstVisibleItemIndex { get; private set; } = 1;

    public bool IsSliderDragging { get; private set; }

    public MangaReaderPage(MangaReaderViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        //var tapGesture = new TapGestureRecognizer();
        //tapGesture.Tapped += OnTapped;
        //MainContent.GestureRecognizers.Add(tapGesture);

        slider.DragStarted += (s, e) =>
        {
            IsSliderDragging = true;
            StopInteraction();
        };

        slider.DragCompleted += (s, e) =>
        {
            StartInteraction();
            IsSliderDragging = false;
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

        MainContent.Scrolled += CollectionView_Scrolled;

        //MainContent.ScrollToRequested += (s, e) =>
        //{
        //    var gg = "";
        //};
        //
        //MainContent.Scrolled += (s, e) =>
        //{
        //    var gg = "";
        //};
    }

    void StartInteraction()
    {
        Timer.Enabled = false;
        Timer.Stop();

        Timer = new()
        {
            AutoReset = false,
            Enabled = true,
            Interval = 5000,
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

    private void CollectionView_Scrolled(object? sender, ItemsViewScrolledEventArgs e)
    {
        if (e.FirstVisibleItemIndex is -1 or 0)
            return;

        FirstVisibleItemIndex = e.FirstVisibleItemIndex;

        if (!IsSliderDragging)
        {
            HideControls();

            IsManuallyScrolling = true;
            slider.Value = FirstVisibleItemIndex;
            IsManuallyScrolling = false;
        }
    }

    private void PagesScrollView_Scrolled(object? sender, ScrolledEventArgs e)
    {
        if (!IsSliderDragging)
        {
            HideControls();
        }

        //var totalHeight = PagesScrollView
        //    .ComputeDesiredSize(double.PositiveInfinity, double.PositiveInfinity)
        //    .Height;
        //
        //var val = ((totalHeight / slider.Maximum) / e.ScrollY) - 1;
        //
        //if (val < slider.Minimum)
        //    val = slider.Minimum;
        //
        //if (val > slider.Maximum)
        //    val = slider.Maximum;
        //
        //slider.Value = (int)val;
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

    //private async void Slider_ValueChanged(object? sender, ValueChangedEventArgs e)
    //{
    //    IsSliderDragging = true;
    //
    //    var totalHeight = PagesScrollView
    //        .ComputeDesiredSize(double.PositiveInfinity, double.PositiveInfinity)
    //        .Height;
    //
    //    var val = (totalHeight / slider.Maximum) * (e.NewValue - 1);
    //
    //    await PagesScrollView.ScrollToAsync(PagesScrollView.X, val, false);
    //
    //    IsSliderDragging = false;
    //}

    private void Slider_ValueChanged(object? sender, ValueChangedEventArgs e)
    {
        if (IsManuallyScrolling)
            return;

        // SliderView becomes visible only after pages are completely loaded.
        // If attempting to scroll while `Entities.Push(pages)`
        if (!SliderView.IsVisible)
            return;

        if (e.NewValue <= 0 || e.NewValue == e.OldValue)
            return;

        //IsSliderDragging = true;

        // Ensure value is `int` only so that an `object` is not passed.
        MainContent.ScrollTo((int)e.NewValue);

        //IsSliderDragging = false;
    }

    //private void Slider_ValueChanged(object sender, ValueChangedEventArgs e)
    //{
    //    PagesScrollView2.ScrollTo((int)e.NewValue);
    //}
}
