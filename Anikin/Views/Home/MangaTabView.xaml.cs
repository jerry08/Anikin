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

public partial class MangaTabView
{
    public MangaTabView()
    {
        InitializeComponent();

        SizeChanged += (_, _) => SetMargins();

        SetupView();

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

    public void SetupView()
    {
        var view = new CarouselView()
        {
            ItemTemplate = new MainDataTemplateSelector()
            {
                DataTemplate = new DataTemplate(() => new MangaCarouselTemplateView()),
            },
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
        }.Bind(ItemsView.ItemsSourceProperty, (MangaHomeViewModel vm) => vm.PopularMedias);

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
                if (BindingContext is MangaHomeViewModel vm)
                {
                    if (!App.IsOnline(false))
                        return;

                    try
                    {
                        view?.ScrollTo((view.Position + 1) % vm.PopularMedias.Count);
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
