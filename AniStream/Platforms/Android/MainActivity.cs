using System;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Content.Res;
using Android.Graphics;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Views.InputMethods;
using AndroidX.Core.View;
using AniStream.Utils;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using static Android.Views.ViewGroup;

namespace AniStream;

[Activity(
    Theme = "@style/Maui.SplashTheme",
    MainLauncher = true,
    SupportsPictureInPicture = true,
    ClearTaskOnLaunch = true,
    ConfigurationChanges = ConfigChanges.ScreenSize
        | ConfigChanges.Orientation
        | ConfigChanges.UiMode
        | ConfigChanges.ScreenLayout
        | ConfigChanges.SmallestScreenSize
        | ConfigChanges.Density
)]
public class MainActivity
    : MauiAppCompatActivity,
        IOnApplyWindowInsetsListener,
        View.IOnTouchListener
{
    public AndroidStoragePermission? AndroidStoragePermission { get; set; }

    public PackageInstallPermission? PackageInstallPermission { get; set; }

    public PlatformMediaController? MediaElementController { get; set; }

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        //FirebaseApp.InitializeApp(this);
        //FirebaseCrashlytics.Instance.SetCrashlyticsCollectionEnabled(true);
        return;

        WindowCompat.SetDecorFitsSystemWindows(Window, false);

        var view1 = FindViewById(Android.Resource.Id.Content);

        ViewCompat.SetOnApplyWindowInsetsListener(view1, this);

        //Window.SetFlags(WindowManagerFlags.LayoutNoLimits, WindowManagerFlags.LayoutNoLimits);

        Window.DecorView.SystemUiVisibility =
            (StatusBarVisibility)SystemUiFlags.LayoutFullscreen
            | (StatusBarVisibility)SystemUiFlags.LayoutStable;

        //Window.DecorView.ViewTreeObserver.GlobalLayout += (s, e) =>
        //{
        //
        //};

        Window.DecorView.ViewTreeObserver.GlobalFocusChange += FocusChanged;

        return;

        var immersiveMode = false;
        var navBarHeight = 0;
        var statusBarHeight = 0;

        if (immersiveMode)
        {
            if (navBarHeight == 0)
            {
                navBarHeight = ViewCompat
                    .GetRootWindowInsets(Window.DecorView.FindViewById(Android.Resource.Id.Content))
                    .GetInsets(WindowInsetsCompat.Type.SystemBars())
                    .Bottom;
            }

            HideStatusBar();

            if (
                Build.VERSION.SdkInt >= BuildVersionCodes.P
                && statusBarHeight == 0
                && Resources.Configuration.Orientation == Android.Content.Res.Orientation.Portrait
            )
            {
                var boundingRects = Window.DecorView.RootWindowInsets?.DisplayCutout?.BoundingRects;
                statusBarHeight = Math.Min(boundingRects[0].Width(), boundingRects[0].Height());
            }
        }
        else
        {
            if (statusBarHeight == 0)
            {
                var windowInsets = ViewCompat.GetRootWindowInsets(
                    Window.DecorView.FindViewById(Android.Resource.Id.Content)
                );
                if (windowInsets != null)
                {
                    var insets = windowInsets.GetInsets(WindowInsetsCompat.Type.SystemBars());
                    statusBarHeight = insets.Top;
                    navBarHeight = insets.Bottom;
                }
            }
        }

        var view = FindViewById(Android.Resource.Id.Content);
        view.SetBackgroundColor(Color.Red);
    }

    void FocusChanged(object sender, ViewTreeObserver.GlobalFocusChangeEventArgs e)
    {
        if (e.OldFocus is not null)
        {
            e.OldFocus.SetOnTouchListener(null);
        }

        if (e.NewFocus is not null)
        {
            e.NewFocus.SetOnTouchListener(this);
        }

        if (e.NewFocus is null && e.OldFocus is not null)
        {
            var imm = InputMethodManager.FromContext(this);

            var wt = e.OldFocus.WindowToken;

            if (imm is null || wt is null)
                return;

            imm.HideSoftInputFromWindow(wt, HideSoftInputFlags.None);
        }
    }

    public override bool DispatchTouchEvent(MotionEvent ev)
    {
        var dispatch = base.DispatchTouchEvent(ev);

        if (ev.Action == MotionEventActions.Down && CurrentFocus is not null)
        {
            if (!KeepFocus)
                CurrentFocus.ClearFocus();
            KeepFocus = false;
        }

        return dispatch;
    }

    bool KeepFocus { get; set; }

    bool OnTouch(View v, MotionEvent e)
    {
        if (e.Action == MotionEventActions.Down && CurrentFocus == v)
            KeepFocus = true;

        return v.OnTouchEvent(e);
    }

    bool View.IOnTouchListener.OnTouch(View v, MotionEvent e) => OnTouch(v, e);

    //public override bool DispatchTouchEvent(MotionEvent? ev)
    //{
    //    if (ev?.Action == MotionEventActions.Down)
    //    {
    //        var view = CurrentFocus;
    //        if (view is EditText editText)
    //        {
    //            editText.ClearFocus();
    //            var imm = (InputMethodManager?)GetSystemService(Context.InputMethodService);
    //            imm?.HideSoftInputFromWindow(view.WindowToken, 0);
    //        }
    //    }
    //
    //    return base.DispatchTouchEvent(ev);
    //}

    public void HideStatusBar()
    {
        Window.AddFlags(Android.Views.WindowManagerFlags.Fullscreen);
    }

    public WindowInsetsCompat OnApplyWindowInsets(View v, WindowInsetsCompat insets1)
    {
        var insets = insets1.GetInsets(WindowInsetsCompat.Type.SystemBars());
        var mlp = (MarginLayoutParams)v.LayoutParameters;
        //mlp.LeftMargin = insets.Left;
        //mlp.BottomMargin = insets.Bottom;
        //mlp.RightMargin = insets.Right;
        //mlp.TopMargin = insets.Top;
        v.LayoutParameters = mlp;

        return WindowInsetsCompat.Consumed;
    }

    protected override void OnActivityResult(
        int requestCode,
        [GeneratedEnum] Result resultCode,
        Intent? data
    )
    {
        base.OnActivityResult(requestCode, resultCode, data);

        AndroidStoragePermission?.OnActivityResult(requestCode, resultCode, data);
        PackageInstallPermission?.OnActivityResult(requestCode, resultCode, data);
    }

    public override void OnRequestPermissionsResult(
        int requestCode,
        string[] permissions,
        [GeneratedEnum] Permission[] grantResults
    )
    {
        Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        base.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        AndroidStoragePermission?.OnRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        );
    }

    protected override void OnResume()
    {
        base.OnResume();
        MediaElementController?.OnResume();
    }

    protected override void OnPause()
    {
        base.OnPause();
        MediaElementController?.MediaElement.Pause();
    }

#pragma warning disable CS0618, CS0672, CA1422
    public override void OnPictureInPictureModeChanged(bool isInPictureInPictureMode)
    {
        MediaElementController?.OnPiPChanged(isInPictureInPictureMode);
        base.OnPictureInPictureModeChanged(isInPictureInPictureMode);
    }

    public override void OnPictureInPictureUiStateChanged(PictureInPictureUiState pipState)
    {
        MediaElementController?.OnPiPChanged(IsInPictureInPictureMode);
        base.OnPictureInPictureUiStateChanged(pipState);
    }

    public override void OnPictureInPictureModeChanged(
        bool isInPictureInPictureMode,
        Configuration? newConfig
    )
    {
        MediaElementController?.OnPiPChanged(isInPictureInPictureMode);
        base.OnPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
    }
#pragma warning restore CS0618, CS0672, CA1422
}
