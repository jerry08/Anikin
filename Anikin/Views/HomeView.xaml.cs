using Android.Content;
using Android.Views;
using Android.Widget;
using AndroidX.CoordinatorLayout.Widget;
using Anikin.ViewModels.Home;
using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Controls.Compatibility.Platform.Android;
using Microsoft.Maui.Devices;
using Microsoft.Maui.Handlers;
using static Android.Provider.MediaStore;
using static Android.Views.ViewGroup;

namespace Anikin.Views;

public partial class HomeView
{
    public HomeView(HomeViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;

        SetMargins();

        SizeChanged += (_, _) => SetMargins();

        //CommunityToolkit.Maui.Alerts.Snackbar.Make("test").Show();
        //Anikin.Controls.Snackbar.Make("test").Show();

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

// Shared view/control
public class MaterialSlider : Microsoft.Maui.Controls.View
{
    public static readonly BindableProperty StepSizeProperty = BindableProperty.Create(
        nameof(StepSize),
        typeof(float),
        typeof(MaterialSlider),
        0f
    );

    public float StepSize
    {
        get { return (float)GetValue(StepSizeProperty); }
        set { SetValue(StepSizeProperty, value); }
    }
}

// Shared handler
public partial class MaterialSliderHandler
{
    public static IPropertyMapper<MaterialSlider, MaterialSliderHandler> PropertyMapper =
        new PropertyMapper<MaterialSlider, MaterialSliderHandler>(ViewHandler.ViewMapper)
        {
            [nameof(MaterialSlider.StepSize)] = MapStepSize,
        };

    public static CommandMapper<MaterialSlider, MaterialSliderHandler> CommandMapper =
        new(ViewCommandMapper) { };

    public MaterialSliderHandler()
        : base(PropertyMapper, CommandMapper) { }
}

// Android Handler
public partial class MaterialSliderHandler : ViewHandler<MaterialSlider, MaterialSliderView>
{
    protected override MaterialSliderView CreatePlatformView() =>
        new MaterialSliderView(Context, VirtualView);

    protected override void ConnectHandler(MaterialSliderView platformView)
    {
        base.ConnectHandler(platformView);

        // Perform any control setup here
    }

    protected override void DisconnectHandler(MaterialSliderView platformView)
    {
        platformView.Dispose();
        base.DisconnectHandler(platformView);
    }

    public static void MapStepSize(MaterialSliderHandler handler, MaterialSlider materialSlider)
    {
        handler.PlatformView?.UpdateStepSize();
    }
}

// Android view
public class MaterialSliderView : CoordinatorLayout
{
    Context _context;
    MaterialSlider _materialSlider;
    Google.Android.Material.Slider.Slider _slider;

    public MaterialSliderView(Context context, MaterialSlider materialSlider)
        : base(context)
    {
        _context = context;
        _materialSlider = materialSlider;

        // Create a RelativeLayout for sizing the video
        var relativeLayout = new RelativeLayout(_context)
        {
            LayoutParameters = new CoordinatorLayout.LayoutParams(
                LayoutParams.MatchParent,
                LayoutParams.MatchParent
            )
            {
                Gravity = (int)GravityFlags.Center
            }
        };

        // Create a VideoView and position it in the RelativeLayout
        _slider = new Google.Android.Material.Slider.Slider(_context)
        {
            LayoutParameters = new RelativeLayout.LayoutParams(
                LayoutParams.MatchParent,
                LayoutParams.MatchParent
            )
        };

        // Add to the layouts
        relativeLayout.AddView(_slider);
        AddView(relativeLayout);
    }

    public void UpdateStepSize()
    {
        _slider.StepSize = _materialSlider.StepSize;
    }
}
