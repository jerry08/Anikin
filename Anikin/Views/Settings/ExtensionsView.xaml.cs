using System.Timers;
using Anikin.ViewModels;
using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace Anikin.Views.Settings;

public partial class ExtensionsView
{
    public ExtensionsView(ExtensionsViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        SizeChanged += (s, e) => SetMargins();

        //SearchEntry.TextChanged += SearchEntry_TextChanged;
        //SearchEntry.Completed += (s, e) =>
        //{
        //    //Timer.Stop();
        //    //Timer.Enabled = false;
        //
        //    ((ExtensionsViewModel?)BindingContext)?.QueryChanged();
        //};
    }

    private void SetMargins()
    {
        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        var navigationBarHeight =
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        //MainGrid.Margin = new Thickness(5, statusBarHeight + 10, 5, navigationBarHeight + 10);

        var leftMargin = 5.0;
        var rightMargin = 5.0;

        if (DeviceDisplay.MainDisplayInfo.Orientation == DisplayOrientation.Landscape)
        {
            leftMargin += navigationBarHeight;
            rightMargin += navigationBarHeight;
        }

        if (statusBarHeight > 0)
            MainGrid.Margin = new Thickness(leftMargin, statusBarHeight + 10, rightMargin, 0);

        if (navigationBarHeight > 0)
            CollectionFooter.HeightRequest = navigationBarHeight + 10;
    }

    private Timer Timer = new();

    private void SearchEntry_TextChanged(object? sender, TextChangedEventArgs e)
    {
        if (e.OldTextValue != e.NewTextValue)
        {
            ((ExtensionsViewModel?)BindingContext)?.QueryChanged();
            return;

            Timer.Enabled = false;
            Timer.Stop();

            Timer = new()
            {
                AutoReset = false,
                Enabled = true,
                Interval = 800
            };

            Timer.Elapsed += (s, e) =>
            {
                Timer.Stop();
                Timer.Enabled = false;

                ((ExtensionsViewModel?)BindingContext)?.QueryChanged();
            };

            Timer.Start();
        }
    }
}
