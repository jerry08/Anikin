using System;
using Plugin.LocalNotification;

namespace AniStream.Utils.Downloading;

public class DownloaderProgress : IProgress<double>, IDisposable
{
    private readonly int _notificationId;
    private readonly string _title;

    public DownloaderProgress(int notificationId, string title)
    {
        _notificationId = notificationId;
        _title = title;
    }

    public void Report(double progress)
    {
        ShowProgressNotification((int)(progress * 100));
    }

    private void ShowProgressNotification(int progress)
    {
        var notification = new NotificationRequest
        {
            Silent = true,
            NotificationId = _notificationId,
            Title = _title,
            Description = "Downloading",
            Android =
            {
                IconSmallName =
                {
                    ResourceName = "logo_transparent_bg",
                },
                Color =
                {
                    ResourceName = "colorPrimary"
                },
                IsProgressBarIndeterminate = false,
                ProgressBarMax = 100,
                ProgressBarProgress = progress,
                //AutoCancel = false,
                Ongoing = true
            }
        };

        LocalNotificationCenter.Current.Show(notification);
    }

    public void Dispose() => GC.SuppressFinalize(this);
}