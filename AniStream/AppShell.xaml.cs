using System.Linq;
using System.Threading.Tasks;
using AniStream.ViewModels.Framework;
using AniStream.Views;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using Microsoft.Maui.Controls;

namespace AniStream;

public partial class AppShell : Shell
{
    private bool DoubleBackToExitPressedOnce { get; set; }

    public AppShell()
    {
        InitializeComponent();

        Routing.RegisterRoute(nameof(SearchView), typeof(SearchView));
        Routing.RegisterRoute(nameof(EpisodePage), typeof(EpisodePage));

        Navigated += async (s, e) =>
        {
            if (CurrentPage?.BindingContext is BaseViewModel viewModel)
            {
                if (!viewModel.IsInitialized)
                    await viewModel.Load();

                viewModel.OnNavigated();
            }
        };

        //Appearing += (s, e) =>
        //{
        //    if (CurrentPage?.BindingContext is BaseViewModel viewModel)
        //    {
        //        viewModel.OnAppearing();
        //    }
        //};
        //
        //Disappearing += (s, e) =>
        //{
        //    if (CurrentPage?.BindingContext is BaseViewModel viewModel)
        //    {
        //        viewModel.OnDisappearing();
        //    }
        //};
    }

    protected override bool OnBackButtonPressed()
    {
        if (
            Current.CurrentPage.BindingContext is CollectionViewModelBase viewModel
            && viewModel.SelectionMode != SelectionMode.None
        )
        {
            viewModel.SelectionMode = SelectionMode.None;
            viewModel.SelectedEntities.Clear();
            return true;
        }

        if (!Current.Navigation.NavigationStack.Any(x => x is not null))
        {
            if (DoubleBackToExitPressedOnce)
            {
                //Application.Current?.Quit();
                //return true;

                return base.OnBackButtonPressed();
            }

            DoubleBackToExitPressedOnce = true;

            Toast.Make("Please perform BACK again to Exit", ToastDuration.Short).Show();

            Task.Run(async () =>
            {
                await Task.Delay(2000);
                DoubleBackToExitPressedOnce = false;
            });

            return true;
        }

        return base.OnBackButtonPressed();
    }
}
