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
using Android.Media;
using Com.Google.Android.Exoplayer2.Video;
using Java.Lang;
using Orientation = Android.Widget.Orientation;
using System.Threading;

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
        string newFilePath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(filePath))
            return;

        var ext = System.IO.Path.GetExtension(newFilePath).Replace(".", "");
        //var dir = System.IO.Directory.GetParent(newFilePath)?.FullName;
        var fileName = System.IO.Path.GetFileNameWithoutExtension(newFilePath);

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension(ext);

        if (mimeType is null)
            return;

        var fileInfo = new FileInfo(filePath);

        var contentValues = new ContentValues();
        //contentValues.Put(MediaStore.IMediaColumns.DisplayName, newFilePath);
        contentValues.Put(MediaStore.IMediaColumns.DisplayName, fileName);
        contentValues.Put(MediaStore.IMediaColumns.MimeType, mimeType);
        contentValues.Put(MediaStore.IMediaColumns.RelativePath, Android.OS.Environment.DirectoryDownloads);
        //contentValues.Put(MediaStore.IMediaColumns.RelativePath, dir);
        contentValues.Put(MediaStore.IMediaColumns.Size, fileInfo.Length);

        if (mimeType.StartsWith("image") || mimeType.StartsWith("video"))
        {
            //Set media duration
            var retriever = new MediaMetadataRetriever();
            retriever.SetDataSource(context, Uri.FromFile(new Java.IO.File(filePath)));
            var time = retriever.ExtractMetadata(MetadataKey.Duration) ?? string.Empty;
            var timeInMillisec = long.Parse(time);
            contentValues.Put(MediaStore.IMediaColumns.Duration, timeInMillisec);
        }

        var resolver = context.ContentResolver;
        var uri = resolver?.Insert(MediaStore.Downloads.ExternalContentUri, contentValues);
        if (uri is not null)
        {
            var defaultBufferSize = 4096;

            using var input = File.OpenRead(filePath);
            var output = resolver?.OpenOutputStream(uri);
            if (output is not null)
                await input.CopyToAsync(output, defaultBufferSize, cancellationToken);
        }
    }
}