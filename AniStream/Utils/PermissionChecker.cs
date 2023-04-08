using Android;
using Android.Content;
using Android.OS;
using AndroidX.Core.Content;

namespace AniStream.Utils;

internal static class PermissionHelper
{
    public static bool HasNotificationPermission(this Context context)
    {
        if (Build.VERSION.SdkInt > BuildVersionCodes.S)
        {
            return ContextCompat.CheckSelfPermission(
                context,
                Manifest.Permission.PostNotifications
            ) == Android.Content.PM.Permission.Granted;
        }

        return true;
    }
}