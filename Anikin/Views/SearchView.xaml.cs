using System.Timers;
using Anikin.ViewModels;
using Berry.Maui;
//using CommunityToolkit.Maui.Alerts;
//using Berry.Maui.Core;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

//using Woka.Helpers.Keyboard;

namespace Anikin.Views;

public partial class SearchView
{
    private const int ItemWidth = 180;

    private DisplayOrientation LastDisplayOrientation { get; set; }

    public SearchView(SearchViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        //Toast.Make("test 1", Berry.Maui.Core.ToastDuration.Long, 20).Show();

        //test24.AnchorX = -10;
        //test24.AnchorY = -10;
        //
        //Snackbar.Make("Test 1", visualOptions: new SnackbarOptions()
        //{
        //    BackgroundColor = Colors.Red,
        //    TextColor = Colors.Blue,
        //    ActionButtonTextColor = Colors.Green,
        //    CornerRadius = 20
        //}, anchor: test24).Show();

        //_keyboardService = keyboardService;

        //var columns = 1 + (int)(Width / 300);
        //(SearchCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;

        LastDisplayOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;

        SizeChanged += (s, e) =>
        {
            SetMargins();

            //var columns = 1 + (int)(Width / ItemWidth);
            var columns =
                1
                + (int)(
                    (MainGrid.Width - (MainGrid.Margin.Left + MainGrid.Margin.Right)) / ItemWidth
                );

            /*//test2.Children.Clear();
            //test2.Children.Add(new HomeViewTextCol(Width));
            //
            //(test2 as IView).InvalidateArrange();
            //(this as IView).InvalidateArrange();

            (SearchCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;
            //(SearchCollectionView.ItemsLayout as GridItemsLayout)!.HorizontalItemSpacing = columns * 7;
            //(SearchCollectionView.ItemsLayout as GridItemsLayout)!.VerticalItemSpacing = columns * 7;

            //SearchCollectionView.ItemsLayout = new GridItemsLayout(columns, ItemsLayoutOrientation.Vertical);

            //viewModel.PopularAnimes.Clear();
            //
            //viewModel.Load();*/

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

            ((SearchViewModel?)BindingContext)?.QueryChanged();
        };
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

                ((SearchViewModel?)BindingContext)?.QueryChanged();
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
