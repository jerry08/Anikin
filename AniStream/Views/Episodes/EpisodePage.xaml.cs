using System;
using AniStream.ViewModels;
using Microsoft.Maui;
using Microsoft.Maui.Controls;

namespace AniStream.Views;

public partial class EpisodePage
{
    public EpisodePage(EpisodeViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        return;

        testImg.TranslateTo(0, 0, 5000);
        testImg.Animate(
            "ChangeMargins",
            length: 5000,
            animation: new Animation(
                x => testImg.Margin = new Thickness(0, 0, 0, x),
                -100,
                0
            //easing: Easing.SinOut
            )
        );
        testImg.Animate(
            "ChangeHeight",
            length: 5000,
            animation: new Animation(
                x => testImg.HeightRequest = x,
                400,
                300
            //easing: Easing.SinOut
            )
        );
    }

    private void CoverImage_OnDoubleTap(object sender, TappedEventArgs e) => ToggleFavourite();

    private void FavouriteButton_OnClick(object sender, EventArgs e) => ToggleFavourite();

    private async void ToggleFavourite()
    {
        if (BindingContext is EpisodeViewModel viewModel)
        {
            viewModel.FavouriteToggleCommand.Execute(null);

            await favouriteBtn.ScaleTo(0.2, 100);
            await favouriteBtn.ScaleTo(2, 100);
            await favouriteBtn.ScaleTo(1, 100);
        }
    }
}
