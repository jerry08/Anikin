using System;
using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Widget;
using AndroidX.Core.App;
using AniStream.Utils.Downloading;
using AniStream.Utils.Extensions;
using DotNetTools.JGrabber.Grabbed;
using Newtonsoft.Json;
using System.Collections.Generic;

namespace AniStream.Services;

public class ServiceHandler : Handler
{
    private readonly DownloadService _downloadService;
    public System.Threading.CancellationTokenSource CancellationTokenSource = new();

    public ServiceHandler(DownloadService service, Looper looper) : base(looper)
    {
        _downloadService = service;
    }

    public override async void HandleMessage(Message msg)
    {
        if (msg.Data is null)
            return;

        var downloader = new HlsDownloader(_downloadService);

        var stream = JsonConvert.DeserializeObject<GrabbedHlsStream>(msg.Data.GetString("stream")!)!;
        var headers = JsonConvert.DeserializeObject<Dictionary<string, string>>(msg.Data.GetString("headers")!)!;
        var fileName = msg.Data.GetString("fileName")!;

        await downloader.DownloadAsync(fileName, stream, headers.ToNameValueCollection(), CancellationTokenSource.Token);

        base.HandleMessage(msg);
    }
}

[Service(Exported = true, Enabled = true, Name = "com.oneb.test1", Process = ":test2")]
public class DownloadService : Service
{
    private Looper mServiceLooper = default!;
    private ServiceHandler mServiceHandler = default!;

    public override void OnCreate()
    {
        base.OnCreate();

        var thread = new HandlerThread("ServiceStartArguments", (int)ThreadPriority.Background);
        thread.Start();

        mServiceLooper = thread.Looper!;
        mServiceHandler = new ServiceHandler(this, mServiceLooper);
    }

    public override void OnTaskRemoved(Intent? rootIntent)
    {
#if DEBUG
        Toast.MakeText(this, "service task removed", ToastLength.Short)?.Show();
#endif
        base.OnTaskRemoved(rootIntent);
    }

    [return: GeneratedEnum]
    public override StartCommandResult OnStartCommand(Intent? intent, [GeneratedEnum] StartCommandFlags flags, int startId)
    {
        if (intent is not null)
        {
            if (intent.Action == "cancel_download")
            {
                mServiceHandler?.CancellationTokenSource.Cancel();

                StopForeground(StopForegroundFlags.Remove);
                StopSelf();
                return StartCommandResult.Sticky;
            }
#if DEBUG
            Toast.MakeText(this, "service started", ToastLength.Short)?.Show();
#endif
            var msg = mServiceHandler.ObtainMessage();
            msg.Arg1 = startId;//needed for stop.

            msg.Data = intent.Extras;

            mServiceHandler.SendMessage(msg);
        }

        return StartCommandResult.Sticky;
    }

    public override IBinder? OnBind(Intent? intent)
    {
        return null;
    }

    public override void OnDestroy()
    {
#if DEBUG
        Toast.MakeText(this, "service destroyed", ToastLength.Short)?.Show();
#endif
        base.OnDestroy();
    }

    public override bool StopService(Intent? name)
    {
#if DEBUG
        Toast.MakeText(this, "service stopped", ToastLength.Short)?.Show();
#endif
        return base.StopService(name);
    }

    public static void SendNotification(Service context, string textTitle, string textContent)
    {
        var intent = new Intent(context, typeof(MainActivity));
        var pendingIntent = PendingIntent.GetActivity(context, 0, intent, PendingIntentFlags.Immutable);

        var channelId = $"{context.PackageName}.general";

        var builder = new NotificationCompat.Builder(context, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(true)
            .SetContentTitle(textTitle)
            .SetContentText(textContent)
            .SetContentIntent(pendingIntent)
            //.SetPriority(NotificationCompat.PriorityDefault);
            .SetPriority(NotificationCompat.PriorityLow);

        context.StartForeground(2387, builder.Build());
    }

    public static void SendNotification(
        Context context,
        int notificationId,
        string textTitle,
        string textContent)
    {
        var intent = new Intent(context, typeof(MainActivity));
        var pendingIntent = PendingIntent.GetActivity(context, 0, intent, PendingIntentFlags.Immutable);

        var channelId = $"{context.PackageName}.general";

        var builder = new NotificationCompat.Builder(context, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(true)
            .SetContentTitle(textTitle)
            .SetContentText(textContent)
            .SetContentIntent(pendingIntent)
            .SetPriority(NotificationCompat.PriorityLow);

        var notificationManager = NotificationManagerCompat.From(context);
        //var notificationManager = (NotificationManager)GetSystemService(NotificationService);

        notificationManager.Notify(notificationId, builder.Build());
    }
}