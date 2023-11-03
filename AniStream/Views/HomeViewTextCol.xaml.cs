using Microsoft.Maui;
using Microsoft.Maui.Controls;

namespace AniStream.Views;

public partial class HomeViewTextCol
{
    double width2;

    public HomeViewTextCol(double width)
        : this()
    {
        width2 = width;
    }

    public HomeViewTextCol()
    {
        InitializeComponent();

        var columns = 1 + (int)(width2 / 500);

        //(AlbumCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;

        AlbumCollectionView.ItemsLayout = new GridItemsLayout(
            columns,
            ItemsLayoutOrientation.Vertical
        );

        (this as IView).InvalidateArrange();

        //viewModel.PopularAnimes.Clear();
        //
        //viewModel.Load();
    }
}
