using System;
using Anikin.ViewModels;
using Anikin.ViewModels.Manga;
using Microsoft.Maui.Controls;

namespace Anikin.Views.Manga;

public partial class MangaPage
{
    public MangaPage(MangaItemViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;
    }

    private void CoverImage_OnDoubleTap(object sender, TappedEventArgs e) => ToggleFavourite();

    private void FavouriteButton_OnClick(object sender, EventArgs e) => ToggleFavourite();

    private async void ToggleFavourite()
    {
        if (BindingContext is MangaItemViewModel viewModel)
        {
            viewModel.FavouriteToggleCommand.Execute(null);

            await favouriteBtn.ScaleTo(0.2, 100);
            await favouriteBtn.ScaleTo(2, 100);
            await favouriteBtn.ScaleTo(1, 100);
        }
    }
}
