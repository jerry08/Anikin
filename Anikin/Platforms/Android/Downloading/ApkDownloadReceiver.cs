using Android.App;
using Android.Content;
using Anikin.Utils.Extensions;
using Microsoft.Maui.ApplicationModel;

namespace Anikin.Utils.Downloading;

[IntentFilter(new[] { DownloadManager.ActionDownloadComplete })]
public class ApkDownloadReceiver : BroadcastReceiver
{
    public const int InstalledApk = 1007;

    public override void OnReceive(Context? context, Intent? intent)
    {
        try
        {
            //Platform.CurrentActivity.ShowToast("Download completed");

            var downloadManager = (DownloadManager)
                Application.Context.GetSystemService(Android.Content.Context.DownloadService)!;

            var downloadId = intent?.GetLongExtra(DownloadManager.ExtraDownloadId, 0) ?? 0;

            var query = new DownloadManager.Query();
            query.SetFilterById(downloadId);

            var c = downloadManager.InvokeQuery(query);
            if (c is null)
                return;

            if (c.MoveToFirst())
            {
                var columnIndex = c.GetColumnIndex(DownloadManager.ColumnStatus);
                if (c.GetInt(columnIndex) == (int)DownloadStatus.Successful)
                {
                    var uri = Android
                        .Net
                        .Uri
                        .Parse(c.GetString(c.GetColumnIndex(DownloadManager.ColumnLocalUri)));

                    if (uri is not null)
                        Platform.CurrentActivity?.InstallApk(uri);
                }
            }
        }
        catch
        {
            // Ignore
        }
    }
}
