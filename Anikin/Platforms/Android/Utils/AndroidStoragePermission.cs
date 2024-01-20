using System;
using System.Linq;
using System.Threading.Tasks;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Microsoft.Maui.ApplicationModel;

namespace Anikin.Utils;

//internal class AndroidStoragePermission : IStoragePermission
public class AndroidStoragePermission
{
    private const int RequestReadWriteExternalStorage = 2230;
    private const int RequestForManageAllFiles = 2231;

    private readonly Activity _activity;
    private TaskCompletionSource<bool> requestPermissionResult;

    public AndroidStoragePermission()
    {
        _activity = Platform.CurrentActivity!;
    }

    public AndroidStoragePermission(Activity context)
    {
        _activity = context;
    }

    public bool HasStoragePermission()
    {
        bool hasPermissions;

        var SDK = Build.VERSION.SdkInt;

        if (SDK > BuildVersionCodes.Q)
        {
            // since sdk 30; stricter permissions requires special 'manage storage permission'
            // requires to go to system settings
            hasPermissions = Android.OS.Environment.IsExternalStorageManager;
        }
        else if (SDK > BuildVersionCodes.M)
        {
            // since sdk 23-28 we request write/read external storage only
            hasPermissions = (
                _activity.PackageManager.CheckPermission(
                    Manifest.Permission.ReadExternalStorage,
                    _activity.PackageName
                ) == Permission.Granted
                && _activity.PackageManager.CheckPermission(
                    Manifest.Permission.WriteExternalStorage,
                    _activity.PackageName
                ) == Permission.Granted
            );
        }
        else
            hasPermissions = true;
        // sdk bellow 23 no permissions needed

        return hasPermissions;
    }

    public Task<bool> RequestStoragePermission()
    {
        var SDK = Build.VERSION.SdkInt;

        if (SDK <= BuildVersionCodes.M)
            return Task.FromResult(true);
        else if (SDK <= BuildVersionCodes.Q)
        {
            requestPermissionResult ??= new TaskCompletionSource<bool>();

            // handled by callback 'OnRequestPermissionsResult'
            _activity.RequestPermissions(
                new string[]
                {
                    Manifest.Permission.ReadExternalStorage,
                    Manifest.Permission.WriteExternalStorage
                },
                RequestReadWriteExternalStorage
            );

            return requestPermissionResult.Task;
        }
        else
        {
            requestPermissionResult ??= new TaskCompletionSource<bool>();
            try
            {
                var intent = new Intent(
                    Android.Provider.Settings.ActionManageAppAllFilesAccessPermission
                );
                intent.AddCategory(Intent.CategoryDefault);
                intent.SetData(Android.Net.Uri.FromParts("package", _activity.PackageName, null));

                // navigates to settings, when user dismisses them calls OnActivityResult with our constant
                _activity.StartActivityForResult(intent, RequestForManageAllFiles);
            }
            catch (Exception)
            {
                // this bad! (probably outdated 'permission model' as android likes to change them every once in a while)
                return Task.FromResult(false);
            }
            return requestPermissionResult.Task;
        }
    }

    /// <summary> Call this in activity OnActivityResult override </summary>
    public void OnActivityResult(int requestCode, Result resultCode, Intent? data)
    {
        if (requestCode == RequestForManageAllFiles)
        {
            if (Build.VERSION.SdkInt > BuildVersionCodes.Q)
            {
                if (Android.OS.Environment.IsExternalStorageManager)
                    requestPermissionResult?.TrySetResult(true);
                else
                    requestPermissionResult?.TrySetResult(false);
            }
        }
    }

    // <summary> Call this in activity OnRequestPermissionsResult override </summary>
    public void OnRequestPermissionsResult(
        int requestCode,
        string[] permissions,
        [GeneratedEnum] Permission[] grantResults
    )
    {
        // make sure we are handling our request
        if (requestCode == RequestReadWriteExternalStorage)
        {
            //
            if (grantResults.Any(item => item.HasFlag(Permission.Denied)))
                requestPermissionResult?.TrySetResult(false);
            else
                requestPermissionResult?.TrySetResult(true);
        }
    }
}
