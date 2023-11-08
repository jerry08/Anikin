using System;
using System.Linq;
using AniStream.ViewModels;
using AniStream.Views.Templates;
using Berry.Maui;
using Berry.Maui.Behaviors;
using CommunityToolkit.Maui.Markup;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace AniStream.Views;

public partial class AnimeTabView
{
    public AnimeTabView()
    {
        InitializeComponent();

        SizeChanged += (_, _) => SetMargins();

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

        SetupView();
        //Loaded += (s, e) => SetupView();

        DeviceDisplay.Current.MainDisplayInfoChanged += (s, e) => SetupView();
    }

    private void SetMargins()
    {
        var statusBarHeight =
            ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        var navigationBarHeight =
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density;

        var leftMargin = 15.0;
        var rightMargin = 15.0;

        if (DeviceDisplay.MainDisplayInfo.Orientation == DisplayOrientation.Landscape)
        {
            leftMargin += navigationBarHeight - 5.0;
            rightMargin += navigationBarHeight - 5.0;
        }

        NavGrid.Margin = new Thickness(leftMargin, statusBarHeight + 10.0, rightMargin, 0);

        if (navigationBarHeight > 0)
            MainGrid.Margin = new Thickness(0, 0, 0, navigationBarHeight + 90);
    }

    /*public void SetupView()
    {
        //if (BindingContext is not HomeViewModel viewModel)
        //    return;

        var view = new CarouselView()
        {
            ItemTemplate = new MainDataTemplateSelector()
            {
                DataTemplate = new DataTemplate(() => new AnimeCarouselTemplateView())
            },
            //ItemsSource = viewModel.CurrentSeasonAnimes,
            IsBounceEnabled = false,
            IsScrollAnimated = false,
            IsSwipeEnabled = true,
            ItemsUpdatingScrollMode = ItemsUpdatingScrollMode.KeepItemsInView,
            PeekAreaInsets = 0,
            ItemsLayout = new LinearItemsLayout(ItemsLayoutOrientation.Horizontal)
            {
                ItemSpacing = 0,
                SnapPointsAlignment = SnapPointsAlignment.Start,
                SnapPointsType = SnapPointsType.MandatorySingle
            }
        };

        view.SetBinding(ItemsView.ItemsSourceProperty, nameof(HomeViewModel.CurrentSeasonAnimes));

        test2.Content = view;
    }*/

    public void SetupView()
    {
        var view = new CarouselView()
        {
            ItemTemplate = new MainDataTemplateSelector()
            {
                DataTemplate = new DataTemplate(() => new AnimeCarouselTemplateView())
            },
            //ItemsSource = viewModel.CurrentSeasonAnimes,
            IsBounceEnabled = false,
            IsScrollAnimated = false,
            IsSwipeEnabled = true,
            ItemsUpdatingScrollMode = ItemsUpdatingScrollMode.KeepItemsInView,
            PeekAreaInsets = 0,
            ItemsLayout = new LinearItemsLayout(ItemsLayoutOrientation.Horizontal)
            {
                ItemSpacing = 0,
                SnapPointsAlignment = SnapPointsAlignment.Start,
                SnapPointsType = SnapPointsType.MandatorySingle
            }
        }
        //.Bind(ItemsView.ItemsSourceProperty, nameof(HomeViewModel.CurrentSeasonAnimes));
        .Bind(ItemsView.ItemsSourceProperty, (HomeViewModel vm) => vm.CurrentSeasonAnimes);

        var isPressing = false;

        var brh = new TouchBehavior();
        //brh.Completed += (s, e) =>
        //{
        //    var gg = "";
        //};
        brh.ShouldMakeChildrenInputTransparent = true;

        //brh.Command = new Command(() =>
        //{
        //    isPressing = true;
        //});
        brh.Completed += (s, e) =>
        {
            isPressing = false;

            //view.Behaviors.Remove(brh);
            //view.Behaviors.Add(brh);
        };

        brh.StateChanged += (s, e) =>
        {
            //isPressing = e.TouchInteractionStatus == TouchInteractionStatus.Started;
            isPressing = e.State == TouchState.Pressed;
        };
        //brh.StatusChanged += (s, e) =>
        //{
        //    isPressing = e.Status == TouchStatus.Started;
        //};

        //view.Behaviors.Add(brh);

        var timer = Dispatcher.CreateTimer();
        timer.Interval = TimeSpan.FromMilliseconds(3000);

        view.Scrolled += (s, e) =>
        {
            timer.Stop();

            timer = Dispatcher.CreateTimer();
            timer.Interval = TimeSpan.FromMilliseconds(4000);
            timer.Tick += (s, e) =>
            {
                //if (isPressing)
                //    return;

                if (BindingContext is HomeViewModel vm)
                {
                    //view.Position = (view.Position + 1) % vm.CurrentSeasonAnimes.Count;
                    view.ScrollTo((view.Position + 1) % vm.CurrentSeasonAnimes.Count);
                    //view.ScrollTo();
                }
            };
            timer.Start();
        };

        view.Loaded += (s, e) =>
        {
            timer.Start();
        };

        timer.Tick += (s, e) =>
        {
            //if (isPressing)
            //    return;

            if (BindingContext is HomeViewModel vm)
            {
                //view.Position = (view.Position + 1) % vm.CurrentSeasonAnimes.Count;
                view.ScrollTo((view.Position + 1) % vm.CurrentSeasonAnimes.Count);
                //view.ScrollTo();
            }
        };

        CarouselContent.Content = view;
    }
}
