using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Media;
using Android.OS;
using Android.Provider;
using Android.Views;
using Android.Webkit;
using Android.Widget;
using AndroidX.Core.Content;
using AndroidX.Core.View;
using Microsoft.Maui.ApplicationModel;
using GSnackbar = Google.Android.Material.Snackbar.Snackbar;
using Path = System.IO.Path;

namespace Anikin.Utils.Extensions;

public static class ActivityExtensions
{
    public static void ShowToast(this Activity? activity, string? text)
    {
        if (activity is null)
            return;

        activity.RunOnUiThread(() => Toast.MakeText(activity, text, ToastLength.Short)!.Show());
    }

    public static void CopyToClipboard(this Activity? activity, string text, bool toast = true)
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
            var snackBar = GSnackbar.Make(
                activity.Window!.DecorView!.FindViewById(Android.Resource.Id.Content)!,
                text,
                GSnackbar.LengthLong
            );
            snackBar.View.LayoutParameters = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WrapContent,
                ViewGroup.LayoutParams.WrapContent
            )
            {
                Gravity = GravityFlags.CenterHorizontal | GravityFlags.Bottom
            };

            snackBar.View.SetBackgroundColor(Color.White);

            //snackBar.View.TranslationY = ;
            snackBar.View.TranslationZ = 32f;
            //snackBar.View.SetPadding(16, 16, 16, 16);

            snackBar.View.Click += (s, e) => snackBar.Dismiss();

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
        windowInsetsController.SystemBarsBehavior =
            WindowInsetsControllerCompat.BehaviorShowTransientBarsBySwipe;

        // Hide both the status bar and the navigation bar
        windowInsetsController.Hide(WindowInsetsCompat.Type.SystemBars());
    }

    public static void ShowSystemBars(this Activity? activity)
    {
        if (activity is null)
            return;

        var windowInsetsController =
            //ViewCompat.GetWindowInsetsController(activity.Window!.DecorView!);
            WindowCompat.GetInsetsController(activity.Window!, activity.Window!.DecorView!);
        if (windowInsetsController is null)
            return;

        // Configure the behavior of the hidden system bars
        windowInsetsController.SystemBarsBehavior =
            WindowInsetsControllerCompat.BehaviorShowBarsByTouch;

        // Hide both the status bar and the navigation bar
        windowInsetsController.Show(WindowInsetsCompat.Type.SystemBars());
    }

    public static void HideStatusBar(this Activity? activity)
    {
        if (activity is null)
            return;

        activity.Window!.AddFlags(WindowManagerFlags.Fullscreen);
    }

    public static async Task CopyFileAsync(
        this Context context,
        string filePath,
        string newFilePath,
        CancellationToken cancellationToken = default
    )
    {
        if (Build.VERSION.SdkInt >= BuildVersionCodes.Q)
        {
            await CopyFileUsingMediaStoreAsync(context, filePath, newFilePath, cancellationToken);
        }
        else
        {
            File.Copy(filePath, newFilePath, true);

            var ext = Path.GetExtension(newFilePath).Replace(".", "");
            var mime = MimeTypeMap.Singleton!;
            var mimeType = mime.GetMimeTypeFromExtension(ext);

            if (!string.IsNullOrEmpty(mimeType))
            {
                MediaScannerConnection.ScanFile(context, [newFilePath], [mimeType], null);
            }
        }
    }

    private static async Task CopyFileUsingMediaStoreAsync(
        this Context context,
        string filePath,
        string newFilePath,
        CancellationToken cancellationToken = default
    )
    {
        if (!File.Exists(filePath))
            return;

        var ext = Path.GetExtension(newFilePath).Replace(".", "");
        //var dir = Directory.GetParent(newFilePath)?.FullName;
        var fileName = Path.GetFileNameWithoutExtension(newFilePath);

        var mime = MimeTypeMap.Singleton!;
        var mimeType = mime.GetMimeTypeFromExtension(ext);

        if (string.IsNullOrEmpty(mimeType))
            return;

        var fileInfo = new FileInfo(filePath);

        var contentValues = new ContentValues();
        //contentValues.Put(MediaStore.IMediaColumns.DisplayName, newFilePath);
        contentValues.Put(MediaStore.IMediaColumns.DisplayName, fileName);
        contentValues.Put(MediaStore.IMediaColumns.MimeType, mimeType);
        contentValues.Put(
            MediaStore.IMediaColumns.RelativePath,
            Android.OS.Environment.DirectoryDownloads
        );
        //contentValues.Put(MediaStore.IMediaColumns.RelativePath, dir);
        contentValues.Put(MediaStore.IMediaColumns.Size, fileInfo.Length);

        if (mimeType.StartsWith("image") || mimeType.StartsWith("video"))
        {
            //Set media duration
            var retriever = new MediaMetadataRetriever();
            retriever.SetDataSource(context, Android.Net.Uri.FromFile(new Java.IO.File(filePath)));
            var time = retriever.ExtractMetadata(MetadataKey.Duration) ?? string.Empty;
            var timeInMillisec = long.Parse(time);
            contentValues.Put(MediaStore.IMediaColumns.Duration, timeInMillisec);
        }

        var resolver = context.ContentResolver;
        var externalContentUri = MediaStore.Files.GetContentUri("external")!;

        //var uri = resolver?.Insert(MediaStore.Downloads.ExternalContentUri, contentValues);
        var uri = resolver?.Insert(externalContentUri, contentValues);
        if (uri is not null)
        {
            var defaultBufferSize = 4096;

            using var input = File.OpenRead(filePath);
            var output = resolver?.OpenOutputStream(uri);
            if (output is not null)
                await input.CopyToAsync(output, defaultBufferSize, cancellationToken);
        }

        MediaScannerConnection.ScanFile(context, [newFilePath], [mimeType], null);
    }

    public static async void InstallApk(this Activity activity, Android.Net.Uri uri)
    {
        try
        {
            if (activity is not MainActivity mainActivity)
                return;

            mainActivity.PackageInstallPermission = new(activity);

            var canRequestPackageInstalls = mainActivity.PackageInstallPermission.CheckStatus();
            if (!canRequestPackageInstalls)
            {
                canRequestPackageInstalls =
                    await mainActivity.PackageInstallPermission.RequestAsync();
            }

            if (!canRequestPackageInstalls)
                return;

            var contentUri = FileProvider.GetUriForFile(
                activity,
                AppInfo.Current.PackageName + ".provider",
                new Java.IO.File(uri.Path!)
            );

            var installIntent = new Intent(Intent.ActionView);
            installIntent.AddFlags(ActivityFlags.GrantReadUriPermission);
            installIntent.AddFlags(ActivityFlags.ClearTop);
            installIntent.PutExtra(Intent.ExtraNotUnknownSource, true);
            //installIntent.SetDataAndType(contentUri);
            installIntent.SetDataAndType(contentUri, "application/vnd.android.package-archive");

            activity.StartActivity(installIntent);
        }
        catch
        {
            // Ignore
        }
    }
}
