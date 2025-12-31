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
