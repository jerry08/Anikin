using System.IO;
using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Net;
using Android.OS;
using Android.Views;
using Android.Widget;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using Java.Net;
using AnimeDl.Scrapers;
using Android.Provider;
using Android.Webkit;
using System.Threading.Tasks;

namespace AniStream.Utils;

public static class WeebUtils
{
    public static AnimeSites AnimeSite { get; set; } = AnimeSites.GogoAnime;

    public static bool IsDubSelected { get; set; } = false;

    public static string PersonalDatabaseFolder
    {
        get
        {
            string pathToMyFolder = System.Environment.GetFolderPath(
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
        int llPadding = 20;
        var ll = new LinearLayout(context);
        ll.Orientation = Orientation.Horizontal;
        ll.SetPadding(llPadding, llPadding, llPadding, llPadding);
        ll.SetGravity(GravityFlags.Center);
        var llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent);
        llParam.Gravity = GravityFlags.Center;
        ll.LayoutParameters = llParam;

        var progressBar = new ProgressBar(context);
        progressBar.Indeterminate = true;
        progressBar.SetPadding(0, 0, llPadding, 0);
        progressBar.LayoutParameters = llParam;

        llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent);
        llParam.Gravity = GravityFlags.Center;

        var tvText = new TextView(context);
        tvText.Text = text;
        tvText.SetTextColor(Color.ParseColor("#ffffff"));
        tvText.TextSize = 18;
        tvText.LayoutParameters = llParam;
        tvText.Id = 12345;

        ll.AddView(progressBar);
        ll.AddView(tvText);

        var builder = new AlertDialog.Builder(context);
        builder.SetCancelable(cancelable);
        builder.SetView(ll);

        AlertDialog dialog = builder.Create();
        dialog.Show();

        var window = dialog.Window;
        if (window is not null)
        {
            //IWindowManager windowManager = this.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();

            var layoutParams = new WindowManagerLayoutParams();
            layoutParams.CopyFrom(dialog.Window.Attributes);
            layoutParams.Width = ViewGroup.LayoutParams.WrapContent;
            layoutParams.Height = ViewGroup.LayoutParams.WrapContent;
            dialog.Window.Attributes = layoutParams;
        }

        return dialog;
    }

    public static bool HasNetworkConnection(Context context)
    {
        var manager = (ConnectivityManager)context.GetSystemService(Context.ConnectivityService)!;
        if (Build.VERSION.SdkInt >= BuildVersionCodes.M)
        {            
            if (manager.ActiveNetwork is null)
                return false;

            var actNw = manager.GetNetworkCapabilities(manager.ActiveNetwork);
            //return actNw is not null && (actNw.HasTransport(TransportType.Wifi) || actNw.HasTransport(TransportType.Cellular) || actNw.HasTransport(TransportType.Ethernet) || actNw.HasTransport(TransportType.Bluetooth));
            //return actNw is not null && (actNw.HasTransport(TransportType.Wifi) || actNw.HasTransport(TransportType.Cellular));
            return actNw is not null &&
                (actNw.HasTransport(TransportType.Wifi)
                || actNw.HasTransport(TransportType.Cellular)
                || actNw.HasTransport(TransportType.Ethernet)
                || actNw.HasTransport(TransportType.Lowpan)
                || actNw.HasTransport(TransportType.Usb)
                || actNw.HasTransport(TransportType.Vpn)
                || actNw.HasTransport(TransportType.WifiAware));
        }
        else
        {
            var nwInfo = manager.ActiveNetworkInfo;
            return nwInfo is not null && nwInfo.IsConnected;
        }

        //bool hasConnectedWifi = false;
        //bool hasConnectedMobile = false;
        //
        //var cm = (ConnectivityManager)context.GetSystemService(Context.ConnectivityService);
        //NetworkInfo[] netInfo = cm.GetAllNetworkInfo();
        //foreach (NetworkInfo ni in netInfo)
        //{
        //    if (ni.TypeName.ToLower().Equals("wifi"))
        //        if (ni.IsConnected)
        //            hasConnectedWifi = true;
        //    if (ni.TypeName.ToLower().Equals("mobile"))
        //        if (ni.IsConnected)
        //            hasConnectedMobile = true;
        //}
        //return hasConnectedWifi || hasConnectedMobile;
    }

    public static async Task CopyFileUsingMediaStore(
        this Context context,
        string filePath,
        string newFilePath)
    {
        if (!File.Exists(filePath))
            return;

        var ext = System.IO.Path.GetExtension(newFilePath).Replace(".", "");
        //var dir = System.IO.Directory.GetParent(newFilePath)?.FullName;
        var fileName = System.IO.Path.GetFileNameWithoutExtension(newFilePath);

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension(ext);

        var fileInfo = new FileInfo(filePath);

        var contentValues = new ContentValues();
        //contentValues.Put(MediaStore.IMediaColumns.DisplayName, newFilePath);
        contentValues.Put(MediaStore.IMediaColumns.DisplayName, fileName);
        contentValues.Put(MediaStore.IMediaColumns.MimeType, mimeType);
        contentValues.Put(MediaStore.IMediaColumns.RelativePath, Android.OS.Environment.DirectoryDownloads);
        //contentValues.Put(MediaStore.IMediaColumns.RelativePath, dir);
        contentValues.Put(MediaStore.IMediaColumns.Size, fileInfo.Length);

        var resolver = context.ContentResolver;
        var uri = resolver?.Insert(MediaStore.Downloads.ExternalContentUri, contentValues);
        if (uri is not null)
        {
            int defaultBufferSize = 4096;

            using var input = File.OpenRead(filePath);
            var output = resolver?.OpenOutputStream(uri);
            if (output is not null)
                await input.CopyToAsync(output, defaultBufferSize);
        }
    }
}