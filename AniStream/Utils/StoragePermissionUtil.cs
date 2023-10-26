using System.Threading.Tasks;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Devices;

namespace AniStream.Utils;

internal class StoragePermissionUtil
{
    public static async Task<PermissionStatus> CheckAndRequestStoragePermission()
    {
        if (DeviceInfo.Platform == DevicePlatform.Android)
        {
            return await CheckAndRequestStorageReadPermission();
        }
        else if (
            DeviceInfo.Platform == DevicePlatform.iOS
            || DeviceInfo.Platform == DevicePlatform.macOS
            || DeviceInfo.Platform == DevicePlatform.MacCatalyst
        )
        {
            return await CheckAndRequestPhotosPermission();
        }

        return PermissionStatus.Granted;
    }

    private static async Task<PermissionStatus> CheckAndRequestStorageReadPermission()
    {
#if ANDROID
        //if (Android.OS.Build.VERSION.SdkInt >= Android.OS.BuildVersionCodes.Q)
        //{
        //    // Android Q and above are going permissionless.
        //
        //    return PermissionStatus.Granted;
        //}


#endif

        var status = await Permissions.RequestAsync<Permissions.StorageRead>();
        if (status != PermissionStatus.Granted)
            return status;

        status = await Permissions.RequestAsync<Permissions.StorageWrite>();
        if (status != PermissionStatus.Granted)
            return status;

        return status;
    }

    private static async Task<PermissionStatus> CheckAndRequestPhotosPermission()
    {
        var status = await Permissions.CheckStatusAsync<Permissions.Photos>();
        if (status == PermissionStatus.Granted)
            return status;

        if (status == PermissionStatus.Denied)
        {
            // Prompt the user to turn on in settings
            // On iOS once a permission has been denied it may not be requested again from the application
            await App.AlertService.ShowAlertAsync(
                "Permission",
                "Please grant photos permission in settings."
            );
            return status;
        }

        status = await Permissions.RequestAsync<Permissions.Photos>();

        return status;
    }
}
