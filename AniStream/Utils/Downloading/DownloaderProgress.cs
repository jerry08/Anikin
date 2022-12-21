using System;
using System.Threading;
using Android.App;
using Android.Content;
using AndroidX.Core.App;
using AndroidX.Core.Content;
using AniStream.Services;

namespace AniStream.Utils.Downloading;

public class DownloaderProgress : IProgress<double>, IDisposable
{
    private readonly Service _service;
    private readonly int _notificationId;
    private readonly string _title;
    
    private Timer? timer;
    private double currentProgress = 0;

    public DownloaderProgress(
        Service service,
        int notificationId,
        string title)
    {
        _service = service;
        _notificationId = notificationId;
        _title = title;

        ShowProgressNotification(0);
    }

    public void Report(double progress)
    {
        //ShowProgressNotification((int)(progress * 100));
        
        timer ??= new Timer(TimerHandler, null, 0, 1000);
        currentProgress = progress;
    }

    private void TimerHandler(object? state)
    {
        ShowProgressNotification((int)(currentProgress * 100));
    }

    private void ShowProgressNotification(int progress)
    {
        var intent = new Intent(_service, typeof(MainActivity));
        var pendingIntent = PendingIntent.GetActivity(_service, 0, intent, PendingIntentFlags.Immutable);

        var cancelIntent = new Intent(_service, typeof(DownloadService));
        cancelIntent.SetAction("cancel_download");
        var cancelPendingIntent = PendingIntent.GetForegroundService(_service, 3462, cancelIntent, PendingIntentFlags.UpdateCurrent);

        var channelId = $"{_service.PackageName}.general";

        var builder = new NotificationCompat.Builder(_service, channelId)
            .SetSmallIcon(Resource.Drawable.logo_notification)
            .SetOngoing(true)
            .SetContentTitle(_title)
            .SetContentText("Downloading")
            .SetContentIntent(pendingIntent)
            .SetProgress(100, progress, false)
            .SetColor(ContextCompat.GetColor(_service, Resource.Color.colorPrimary))
            .AddAction(Resource.Drawable.logo_notification, "Cancel", cancelPendingIntent)
            .SetPriority(NotificationCompat.PriorityLow);

        _service.StartForeground(_notificationId, builder.Build());
    }

    public void Dispose()
    {
        timer?.Dispose();
        timer = null;
        GC.SuppressFinalize(this);
    }
}