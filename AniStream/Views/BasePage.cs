using AniStream.ViewModels.Framework;
using Microsoft.Maui.Controls;

namespace AniStream.Views;

public class BasePage : ContentPage
{
    protected override void OnAppearing()
    {
        base.OnAppearing();

        if (BindingContext is BaseViewModel viewModel)
        {
            viewModel.OnAppearing();
        }
    }

    protected override void OnDisappearing()
    {
        base.OnDisappearing();

        if (BindingContext is BaseViewModel viewModel)
        {
            viewModel.OnDisappearing();
        }
    }
}
