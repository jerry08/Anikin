using System;
using Anikin.ViewModels.Home;
using Anikin.Views.Templates;
using Berry.Maui;
using CommunityToolkit.Maui.Markup;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;
using Microsoft.Maui.Dispatching;

namespace Anikin.Views.Home;

public partial class AnimeTabView
{
    public AnimeTabView(AnimeHomeViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

        SetupView();

        DeviceDisplay.Current.MainDisplayInfoChanged += (s, e) => SetupView();
    }

    public void SetupView()
    {
        var view = new CarouselView()
        {
            ItemTemplate = new MainDataTemplateSelector()
            {
                DataTemplate = new DataTemplate(() => new AnimeCarouselTemplateView()),
            },
            //ItemsSource = viewModel.CurrentSeasonMedias,
            IsBounceEnabled = false,
            IsScrollAnimated = false,
            IsSwipeEnabled = true,
            ItemsUpdatingScrollMode = ItemsUpdatingScrollMode.KeepItemsInView,
            PeekAreaInsets = 0,
            ItemsLayout = new LinearItemsLayout(ItemsLayoutOrientation.Horizontal)
            {
                ItemSpacing = 0,
                SnapPointsAlignment = SnapPointsAlignment.Start,
                SnapPointsType = SnapPointsType.MandatorySingle,
            },
        }
        //.Bind(ItemsView.ItemsSourceProperty, nameof(AnimeHomeViewModel.CurrentSeasonMedias));
        .Bind(ItemsView.ItemsSourceProperty, (AnimeHomeViewModel vm) => vm.CurrentSeasonMedias);

        IDispatcherTimer? timer = null;

        view.Scrolled += (_, _) => SetTimer();
        view.Loaded += (_, _) => SetTimer();

        void SetTimer()
        {
            timer?.Stop();

            timer = Dispatcher.CreateTimer();
            timer.Interval = TimeSpan.FromMilliseconds(4200);
            timer.Tick += (s, e) =>
            {
                if (BindingContext is AnimeHomeViewModel vm)
                {
                    if (!App.IsOnline(false))
                        return;

                    try
                    {
                        //view.Position = (view.Position + 1) % vm.CurrentSeasonMedias.Count;
                        view?.ScrollTo((view.Position + 1) % vm.CurrentSeasonMedias.Count);
                        //view.ScrollTo();
                    }
                    catch
                    {
                        // Ignore
                    }
                }
            };
            timer.Start();
        }

        CarouselContent.Content = view;
    }
}
