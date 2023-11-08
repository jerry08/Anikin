using AniStream.ViewModels;
using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Devices;

namespace AniStream.Views;

public partial class HomeView
{
    public HomeView(HomeViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        SizeChanged += (_, _) => SetMargins();

        //CommunityToolkit.Maui.Alerts.Snackbar.Make("test").Show();
        //AniStream.Controls.Snackbar.Make("test").Show();

        //CommunityToolkit.Maui.Alerts.Toast.Make("tes").Show();
        // Same
        //Toast.MakeText(Platform.CurrentActivity, "test", ToastLength.Long).Show();
        //return;

        //var statusBarHeight = ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        //var navigationBarHeight1 = ApplicationEx.GetNavigationBarHeight();
        //var navigationBarHeight2 = (int)(ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density);
        //
        //var v = Platform.CurrentActivity.Window.DecorView.FindViewById(Android.Resource.Id.Content);
        //var snackBar = Snackbar.Make(v, "test", Snackbar.LengthLong);
        //snackBar.View.LayoutParameters = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent)
        //{
        //    Gravity = GravityFlags.CenterHorizontal | GravityFlags.Bottom,
        //};
        //snackBar.View.TranslationY = -(navigationBarHeight1 + 32f);
        //snackBar.View.TranslationZ = 32f;
        //snackBar.View.SetPadding(16, 0, 16, 0);
        //snackBar.Show();
    }

    private void SetMargins()
    {
        var navigationBarHeight = (int)(
            ApplicationEx.GetNavigationBarHeight() / DeviceDisplay.MainDisplayInfo.Density
        );

        if (navigationBarHeight > 0)
            ViewContent.Margin = new Thickness(0, 0, 0, navigationBarHeight + 10);
    }
}
