using System.IO;
using Android.Content;
using Android.Graphics;
using Android.Views;
using Android.Widget;
using AnimeDl.Scrapers;
using Microsoft.Maui.Networking;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using Orientation = Android.Widget.Orientation;

namespace AniStream.Utils;

public static class WeebUtils
{
    public static AnimeSites AnimeSite { get; set; } = AnimeSites.GogoAnime;

    public static bool IsDubSelected { get; set; } = false;

    public static string PersonalDatabaseFolder
    {
        get
        {
            var pathToMyFolder = System.Environment.GetFolderPath(
                System.Environment.SpecialFolder.Personal) + "/user/database";

            if (!Directory.Exists(pathToMyFolder))
                Directory.CreateDirectory(pathToMyFolder);

            return pathToMyFolder;
        }
    }

    public static string AppFolder
    {
        get
        {
            return System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.Personal), AppFolderName);
        }
    }

    public static string AppFolderName { get; set; } = default!;

    public static AlertDialog SetProgressDialog(
        Context context,
        string text,
        bool cancelable)
    {
        var llPadding = 20;

        var ll = new LinearLayout(context)
        {
            Orientation = Orientation.Horizontal
        };
        ll.SetPadding(llPadding, llPadding, llPadding, llPadding);
        ll.SetGravity(GravityFlags.Center);

        var llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent)
        {
            Gravity = GravityFlags.Center,
        };
        ll.LayoutParameters = llParam;

        var progressBar = new ProgressBar(context)
        {
            Indeterminate = true,
            LayoutParameters = llParam
        };
        progressBar.SetPadding(0, 0, llPadding, 0);

        llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent)
        {
            Gravity = GravityFlags.Center
        };

        var tvText = new TextView(context)
        {
            Text = text,
            TextSize = 18,
            LayoutParameters = llParam,
            Id = 12345
        };
        tvText.SetTextColor(Color.ParseColor("#000000"));

        ll.AddView(progressBar);
        ll.AddView(tvText);

        var builder = new AlertDialog.Builder(context, Resource.Style.DialogTheme);
        builder.SetCancelable(cancelable);
        builder.SetView(ll);

        var dialog = builder.Create();
        dialog.Show();

        if (dialog.Window is not null)
        {
            //var windowManager = this.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();

            var layoutParams = new WindowManagerLayoutParams();
            layoutParams.CopyFrom(dialog.Window.Attributes);
            layoutParams.Width = ViewGroup.LayoutParams.WrapContent;
            layoutParams.Height = ViewGroup.LayoutParams.WrapContent;
            dialog.Window.Attributes = layoutParams;
        }

        return dialog;
    }

    public static bool IsOnline()
        => Connectivity.Current.NetworkAccess == NetworkAccess.Internet;
}