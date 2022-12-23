using Android.App;
using Android.Views;
using Android.Widget;
using Android.Content;
using AndroidX.Core.View;
using Google.Android.Material.Snackbar;
using Android.Graphics;

namespace AniStream.Utils.Extensions;

public static class ActivityExtensions
{
    public static void ShowToast(this Activity? activity, string? text)
    {
        if (activity is null)
            return;

        activity.RunOnUiThread(() =>
        {
            Toast.MakeText(activity, text, ToastLength.Short)!.Show();
        });
    }

    public static void CopyToClipboard(this Activity? activity,
        string text, bool toast = true)
    {
        if (activity is null)
            return;

        var clipboard = (ClipboardManager)activity.GetSystemService(Context.ClipboardService)!;
        var clip = ClipData.NewPlainText("label", text);
        clipboard.PrimaryClip = clip;
        if (toast)
            ToastString(activity, $"Copied \"{text}\"");
    }

    public static void ToastString(this Activity? activity, string? text)
    {
        if (activity is null || text is null)
            return;

        activity.RunOnUiThread(() =>
        {
            var snackBar = Snackbar.Make(activity.Window!.DecorView!.FindViewById(Android.Resource.Id.Content)!, text, Snackbar.LengthLong);
            snackBar.View.LayoutParameters = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent)
            {
                Gravity = GravityFlags.CenterHorizontal | GravityFlags.Bottom
            };

            snackBar.View.SetBackgroundColor(Color.White);

            //snackBar.View.TranslationY = ;
            snackBar.View.TranslationZ = 32f;
            //snackBar.View.SetPadding(16, 16, 16, 16);

            snackBar.View.Click += (s, e) =>
            {
                snackBar.Dismiss();
            };

            snackBar.View.LongClick += (s, e) =>
            {
                CopyToClipboard(activity, text, false);
                ShowToast(activity, text);
            };

            snackBar.Show();
        });
    }

    public static void HideSystemBars(this Activity? activity)
    {
        if (activity is null)
            return;

        var windowInsetsController =
           //ViewCompat.GetWindowInsetsController(activity.Window!.DecorView!);
           WindowCompat.GetInsetsController(activity.Window!, activity.Window!.DecorView!);
        if (windowInsetsController is null)
            return;

        // Configure the behavior of the hidden system bars
        windowInsetsController.SystemBarsBehavior = WindowInsetsControllerCompat
            .BehaviorShowTransientBarsBySwipe;

        // Hide both the status bar and the navigation bar
        windowInsetsController.Hide(WindowInsetsCompat.Type.SystemBars());
    }

    public static void HideStatusBar(this Activity? activity)
    {
        if (activity is null)
            return;

        activity.Window!.AddFlags(WindowManagerFlags.Fullscreen);
    }
}