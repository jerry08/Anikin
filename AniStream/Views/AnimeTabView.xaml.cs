using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace AniStream.Views;

public class Test1 { }

public partial class AnimeTabView
{
    public AnimeTabView()
    {
        InitializeComponent();

        var navigationBarHeight = (int)(
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density
        );
        if (navigationBarHeight > 0)
            MainGrid.Margin = new Thickness(0, 0, 0, navigationBarHeight + 100);

        SizeChanged += (s, e) =>
        {
            return;

            var columns = 1 + (int)(Width / 400);

            //test2.Children.Clear();
            //test2.Children.Add(new HomeViewTextCol(Width));
            //
            //(test2 as IView).InvalidateArrange();
            //(this as IView).InvalidateArrange();

            (AlbumCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;
            //(AlbumCollectionView.ItemsLayout as GridItemsLayout)!.HorizontalItemSpacing = columns * 7;
            //(AlbumCollectionView.ItemsLayout as GridItemsLayout)!.VerticalItemSpacing = columns * 7;

            //AlbumCollectionView.ItemsLayout = new GridItemsLayout(columns, ItemsLayoutOrientation.Vertical);

            //viewModel.PopularAnimes.Clear();
            //
            //viewModel.Load();
        };

        test3.ItemsSource = new[] { new Test1(), new Test1(), new Test1() };

        //img1.Loaded += delegate
        //{
        //    img1.IsAnimationPlaying = false;
        //
        //    Task.Run(async () =>
        //    {
        //        await Task.Delay(500);
        //        img1.IsAnimationPlaying = true;
        //    });
        //};

        //Snackbar.Make("Test1.", anchor: tabHostView).Show();
        //Toast.Make("Test2.").Show();
    }
}
