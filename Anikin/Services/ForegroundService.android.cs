using System;
using System.Diagnostics.CodeAnalysis;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Util;
using AndroidX.Lifecycle;
using Anikin.Utils;
using Anikin.ViewModels;

namespace Anikin.Services;

//[Service(Exported = true, Enabled = true, Name = "com.oneb.anikinservice", Process = ":anikindownloader")]
[Service(Exported = true, Enabled = true, Name = "com.oneb.anikinservice")]
public class ForegroundService : LifecycleService
{
    public const string Tag = "Foreground Service";

    public PowerManager.WakeLock? WakeLock { get; set; }

    public static bool IsServiceStarted { get; set; }

    class DownloadServiceBinder : Binder
    {
        public DownloadServiceBinder() { }
    }

    private readonly IBinder myBinder = new DownloadServiceBinder();

    public override IBinder? OnBind(Intent intent)
    {
        base.OnBind(intent);
        return myBinder;
    }

    public override void OnCreate()
    {
        base.OnCreate();

        NotificationHelper.ShowNotification(this, "Running", "Running...");
    }

    [return: GeneratedEnum]
    public override StartCommandResult OnStartCommand(
        Intent? intent,
        [GeneratedEnum] StartCommandFlags flags,
        int startId
    )
    {
        base.OnStartCommand(intent, flags, startId);

        // Send a notification that service is started
        //SendNotification(this, "Downloading", "Downloading...");

        // Send a notification that service is started
        Log.Info(Tag, "Foreground Service Started.");

        if (intent?.Action == "kill")
        {
            KillService();
        }

        // Wake locks and misc tasks from here :
        if (IsServiceStarted)
        {
            // Service Already Started
            return StartCommandResult.Sticky;
        }
        else
        {
            IsServiceStarted = true;

            Log.Info(Tag, "Starting the foreground service task");

            WakeLock = PowerManager
                .FromContext(this)
                ?.NewWakeLock(WakeLockFlags.Partial, "EndlessService::lock");
            WakeLock?.Acquire();

            Log.Info(Tag, "Started the foreground service task");

            StartScan();

            return StartCommandResult.Sticky;
        }
    }

    private void StartScan()
    {
        Task.Run(async () =>
        {
            while (DownloadViewModel.Downloads.Count > 0)
            {
                await Task.Delay(3000);
            }

            if (IsServiceStarted)
            {
                KillService();
            }
        });
    }

    public override void OnTaskRemoved(Intent? rootIntent)
    {
        base.OnTaskRemoved(rootIntent);

        Log.Info(Tag, "Task removed");
    }

    private void ReleaseWakeLock()
    {
        Log.Debug(Tag, "Releasing Wake Lock");

        try
        {
            if (WakeLock?.IsHeld == true)
                WakeLock?.Release();
        }
        catch (Exception e)
        {
            Log.Debug(Tag, $"Service stopped without being started: {e.Message}");
        }

        IsServiceStarted = false;
    }

    private void KillService()
    {
        try
        {
            DownloadViewModel.Downloads.ForEach(download => download.Cancel());
        }
        catch { }

        ReleaseWakeLock();

        if (OperatingSystem.IsAndroidVersionAtLeast(24))
        {
            StopForeground(StopForegroundFlags.Remove);
            StopSelf();
        }
        else
        {
            StopSelf();
            StopForeground(true);
        }
    }
}
