using System;
using Android.App;
using Android.Content;
using AndroidX.Core.App;
using Anikin.Services;
using Microsoft.Maui.ApplicationModel;

namespace Anikin.Utils;

public static partial class NotificationHelper
{
    public const string ChannelId = "ForegroundDownloaderService";
    public const int NotificationId = 2782;
    public const int CompletedNotificationId = 2683;
    public const int CancelIntentRequestCode = 3463;

    public static void ShowNotification(Service service, string textTitle, string textContent)
    {
        var flags = OperatingSystem.IsAndroidVersionAtLeast(23)
            ? PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable
            : PendingIntentFlags.UpdateCurrent;

        var intent = new Intent(service, typeof(MainActivity));
        var pendingIntent = PendingIntent.GetActivity(service, 0, intent, flags);

        var cancelIntent = new Intent(service, typeof(ForegroundService));
        cancelIntent.SetAction("kill");

        var cancelPendingIntent = OperatingSystem.IsAndroidVersionAtLeast(26)
            ? PendingIntent.GetForegroundService(
                service,
                CancelIntentRequestCode,
                cancelIntent,
                flags
            )
            : PendingIntent.GetService(service, CancelIntentRequestCode, cancelIntent, flags);

        var channelId = $"{service.PackageName}.general";

        var builder = new NotificationCompat.Builder(service, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(true)
            .SetContentTitle(textTitle)
            .SetContentText(textContent)
            .SetContentIntent(pendingIntent)
            .SetProgress(100, 100, true)
            .AddAction(Resource.Drawable.logo_notification, "Cancel All", cancelPendingIntent)
            //.SetPriority(NotificationCompat.PriorityDefault);
            .SetPriority(NotificationCompat.PriorityLow);

        service.StartForeground(NotificationId, builder.Build());
    }

    public static void ShowCompletedNotification(string contentText = "Completed")
    {
        var context = Platform.AppContext;

        var channelId = $"{context.PackageName}.general";

        //Application.Context.Resources?.GetIdentifier();

        var builder = new NotificationCompat.Builder(context, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            //.SetOngoing(true)
            .SetContentTitle("Yosu")
            .SetContentText(contentText)
            .SetPriority(NotificationCompat.PriorityLow);

        var notificationManager = NotificationManagerCompat.From(context);
        //var notificationManager = (NotificationManager)GetSystemService(NotificationService);

        notificationManager.Notify(CompletedNotificationId, builder.Build());
    }

    public static void StartForeground()
    {
        var activity = Platform.CurrentActivity;
        if (activity is null)
            return;

        var intent = new Intent(activity, typeof(ForegroundService));

        //intent.PutExtra("fileName", fileName);

        //if (Android.OS.Build.VERSION.SdkInt > Android.OS.BuildVersionCodes.O)
        if (OperatingSystem.IsAndroidVersionAtLeast(26))
        {
            activity.StartForegroundService(intent);
        }
        else
        {
            activity.StartService(intent);
        }
    }

    public static void StopForeground()
    {
        var activity = Platform.CurrentActivity;
        if (activity is null)
            return;

        var intent = new Intent(activity, typeof(ForegroundService));

        intent.SetAction("kill");

        //intent.PutExtra("fileName", fileName);

        if (OperatingSystem.IsAndroidVersionAtLeast(26))
        {
            activity.StartForegroundService(intent);
        }
        else
        {
            activity.StartService(intent);
        }

        //if (!ApplicationEx.IsRunning())
        //    Current?.Quit();
    }
}
