using System.Collections.Generic;
using System.Threading.Tasks;
using Foundation;

namespace Anikin.Services;

public class DownloadServiceImpl : IDownloadService
{
    public static DownloadServiceImpl Create() => new();

    public async Task EnqueueAsync(
        string fileName,
        string url,
        IDictionary<string, string>? headers = null
    )
    {
        var configuration = NSUrlSessionConfiguration.CreateBackgroundSessionConfiguration(
            "com.SimpleBackgroundTransfer.BackgroundSession"
        );
        var session = NSUrlSession.FromConfiguration(
            configuration,
            new MySessionDelegate(),
            new NSOperationQueue()
        );

        var downloadUrl = NSUrl.FromString(url);
        if (downloadUrl is null)
            return;

        var request = NSUrlRequest.FromUrl(downloadUrl);
        var downloadTask = await session.CreateDownloadTaskAsync(request);
    }
}

public class MySessionDelegate : NSObject, INSUrlSessionDownloadDelegate
{
    public void DidFinishDownloading(
        NSUrlSession session,
        NSUrlSessionDownloadTask downloadTask,
        NSUrl location
    ) { }

    public void DidWriteData(
        NSUrlSession session,
        NSUrlSessionDownloadTask downloadTask,
        long bytesWritten,
        long totalBytesWritten,
        long totalBytesExpectedToWrite
    )
    {
        //Console.WriteLine(string.Format("DownloadTask: {0}  progress: {1}", downloadTask, progress));
        //InvokeOnMainThread(() => {
        //    // update UI with progress bar, if desired
        //});
    }
}
