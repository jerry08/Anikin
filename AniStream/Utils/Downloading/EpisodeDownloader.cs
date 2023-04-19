using System.Threading;
using System.Threading.Tasks;
using Juro.Models.Anime;
using Juro.Models.Videos;
using Microsoft.Maui.ApplicationModel;

namespace AniStream.Utils.Downloading;

public class EpisodeDownloader
{
    public async Task EnqueueAsync(
        AnimeInfo anime,
        Episode episode,
        VideoSource video)
    {
        if (Platform.CurrentActivity is null)
            return;

        var androidStoragePermission = new AndroidStoragePermission(Platform.CurrentActivity);

        if (Platform.CurrentActivity is ActivityBase activity)
            activity.AndroidStoragePermission = androidStoragePermission;

        var hasStoragePermission = androidStoragePermission.HasStoragePermission();
        if (!hasStoragePermission)
            hasStoragePermission = await androidStoragePermission.RequestStoragePermission();

        if (!hasStoragePermission)
            return;

        var downloader = new Downloader(Platform.CurrentActivity);

        if (video.Format == VideoType.Container)
        {
            downloader.Download($"{anime.Title} - Ep-{episode.Number}.mp4", video.VideoUrl, video.Headers);
        }
        else
        {
            await downloader.DownloadHls(
                $"{anime.Title} - Ep-{episode.Number}.mp4",
                video.VideoUrl,
                video.Headers);
        }
    }
}