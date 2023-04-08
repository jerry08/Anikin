using System;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Runtime;
using Android.Util;
using AndroidX.AppCompat.App;
using AniStream.Utils;
using AniStream.Utils.Downloading;
using Microsoft.Maui.ApplicationModel;

namespace AniStream;

public class ActivityBase : AppCompatActivity
{
    public const string Tag = "AniStream";

    public AndroidStoragePermission? AndroidStoragePermission { get; set; }

    protected override void OnActivityResult(int requestCode, [GeneratedEnum] Result resultCode, Intent? data)
    {
        base.OnActivityResult(requestCode, resultCode, data);

        AndroidStoragePermission?.OnActivityResult(requestCode, resultCode, data);

        try
        {
            if (requestCode == ApkDownloadReceiver.InstalledApk
                && this.IsPackageInstalled("com.oneb.anistreamffmpeg"))
            {
                var intent = new Intent();
                intent.SetClassName("com.oneb.anistreamffmpeg", "com.oneb.anistreamffmpeg.MainActivity");
                //intent.SetFlags(ActivityFlags.SingleTop);
                intent.SetFlags(ActivityFlags.FromBackground);
                StartActivity(intent);
            }
        }
        catch (Exception e)
        {
            Log.Debug(Tag, $"{e}");
        }
    }

    public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Permission[] grantResults)
    {
        Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        base.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        AndroidStoragePermission?.OnRequestPermissionsResult(requestCode, permissions, grantResults);
    }
}