using Microsoft.Maui.Devices;
using The49.Maui.BottomSheet;

namespace AniStream.Views.BottomSheets;

public partial class EpisodeSelectionSheet
{
    public EpisodeSelectionSheet()
    {
        InitializeComponent();

        SetHeights();

        Shown += (_, _) => DeviceDisplay.Current.MainDisplayInfoChanged += OnMainDisplayInfoChanged;

        Dismissed += (_, _) => DeviceDisplay.Current.MainDisplayInfoChanged -= OnMainDisplayInfoChanged;

        //this.UpdateChildrenLayout();
    }

    private void OnMainDisplayInfoChanged(object? sender, DisplayInfoChangedEventArgs e)
    {
        SetHeights();
    }

    public void SetHeights()
    {
        //if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        //{
        //    this.Padding = new Microsoft.Maui.Thickness(0, 50, 0, 0);
        //    this.Margin = new Microsoft.Maui.Thickness(0, 50, 0, 0);
        //}
        //else
        //{
        //    this.Padding = new Microsoft.Maui.Thickness(0, 0, 0, 0);
        //    this.Margin = new Microsoft.Maui.Thickness(0, 0, 0, 0);
        //}

        //if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        //{
        //    //((RatioDetent)this.Detents[1]).Ratio = 0.85f;
        //
        //    this.Detents[2].IsDefault = false;
        //    //this.Detents[1] = new RatioDetent() { Ratio = 0.85f };
        //    this.Detents[2].IsEnabled = false;
        //}
        //else
        //{
        //    //this.Detents[1] = new FullscreenDetent();
        //
        //    //((RatioDetent)this.Detents[1]).Ratio = 1f;
        //
        //    this.Detents[2].IsDefault = true;
        //    this.Detents[2].IsEnabled = true;
        //}

        return;

        if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        {
            Main.HeightRequest = 600;
        }
        else
        {
            Main.HeightRequest = -1;
        }
        return;

        var hh = (DeviceDisplay.MainDisplayInfo.Height / DeviceDisplay.MainDisplayInfo.Density);

        //var test3 = this.Content.Measure(this.Window.Width - this.Padding.HorizontalThickness, 600);

        if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        {
            Main.HeightRequest = 600;
        }
        else
        {
            //var test = (page.Content as ScrollView)?.Content.Measure(page.Window.Width - page.Padding.HorizontalThickness, maxSheetHeight);
            //var test = this.Content.Measure(this.Window.Width - this.Padding.HorizontalThickness, 600);

            var gs1 = this.Height;
            var gs2 = this.Content.Height;

            var gs11 = this.HeightRequest;
            var gs22 = this.Content.HeightRequest;

            var gs3 = Main.Height;
            var gs4 = Main.HeightRequest;

            //this.Content.HeightRequest = hh;
            test24.HeightRequest = hh;
        }

        return;

        if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        {
            ((HeightDetent)this.Detents[1]).Height = 700;
        }
        else
        {
            ((HeightDetent)this.Detents[1]).Height = 400;
        }

        return;

        if (DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait)
        {
            // Remove effective height for portrait mode only
            //test24.HeightRequest = -1;
            //Main.HeightRequest = 400;
            Main.HeightRequest = (DeviceDisplay.MainDisplayInfo.Height / DeviceDisplay.MainDisplayInfo.Density) * 0.75;
            return;
        }

        //Main.HeightRequest = (DeviceDisplay.MainDisplayInfo.Height / DeviceDisplay.MainDisplayInfo.Density) * 0.5;
        return;

        //test24.HeightRequest = 400;

        //test24.IsVisible = false;
        //test24.IsVisible = true;

        //test24.HeightRequest = test24.Height / DeviceDisplay.MainDisplayInfo.Density;
        test24.HeightRequest =
            (DeviceDisplay.MainDisplayInfo.Height / DeviceDisplay.MainDisplayInfo.Density) - 60;
        test24.HeightRequest += test24.Margin.Top;
        test24.HeightRequest += test24.Margin.Bottom;
    }
}
