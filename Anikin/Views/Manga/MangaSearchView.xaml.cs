using System.Timers;
using Anikin.ViewModels.Manga;
using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace Anikin.Views.Manga;

public partial class MangaSearchView
{
    private const int ItemWidth = 180;

    private DisplayOrientation LastDisplayOrientation { get; set; }

    public MangaSearchView(MangaSearchViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        LastDisplayOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;

        SizeChanged += (s, e) =>
        {
            SetMargins();

            var columns =
                1
                + (int)(
                    (MainGrid.Width - (MainGrid.Margin.Left + MainGrid.Margin.Right)) / ItemWidth
                );

            // Fix Maui bug where margins are reducing view when rotating device from
            // Portrait to Landscape then back to Portrait
            if (LastDisplayOrientation != DeviceDisplay.Current.MainDisplayInfo.Orientation)
            {
                LastDisplayOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;
                SearchCollectionView.ItemsLayout = new GridItemsLayout(
                    columns,
                    ItemsLayoutOrientation.Vertical
                );
            }
            else
            {
                (SearchCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;
            }
        };

        Shell.Current.Navigated += Current_Navigated;

        SearchEntry.TextChanged += SearchEntry_TextChanged;
        SearchEntry.Completed += (s, e) =>
        {
            Timer.Stop();
            Timer.Enabled = false;

            ((MangaSearchViewModel?)BindingContext)?.QueryChanged();
        };
    }

    private void SetMargins()
    {
        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        var navigationBarHeight =
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density;

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
            Timer.Enabled = false;
            Timer.Stop();

            Timer = new()
            {
                AutoReset = false,
                Enabled = true,
                Interval = 800,
            };

            Timer.Elapsed += (s, e) =>
            {
                Timer.Stop();
                Timer.Enabled = false;

                ((MangaSearchViewModel?)BindingContext)?.QueryChanged();
            };

            Timer.Start();
        }
    }

    private void Current_Navigated(object? sender, ShellNavigatedEventArgs e)
    {
        Shell.Current.Navigated -= Current_Navigated;
        SearchEntry.ShowKeyboard();
    }
}
