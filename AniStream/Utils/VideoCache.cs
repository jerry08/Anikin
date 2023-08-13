using Android.Content;
using Com.Google.Android.Exoplayer2.Database;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using Java.IO;
using Microsoft.Maui.Storage;

namespace AniStream.Utils;

internal static class VideoCache
{
    private static SimpleCache? _simpleCache;

    public static SimpleCache GetInstance(Context context)
    {
        var databaseProvider = new StandaloneDatabaseProvider(context);

        if (_simpleCache is null)
        {
            var file = new File(context.CacheDir, "exoplayer");
            file.DeleteOnExit();

            _simpleCache = new SimpleCache(
                file,
                new LeastRecentlyUsedCacheEvictor(300L * 1024L * 1024L),
                databaseProvider
            );
        }

        return _simpleCache;
    }

    public static void Release()
    {
        try
        {
            var dir = System.IO.Path.Combine(FileSystem.CacheDirectory, "exoplayer");
            System.IO.Directory.Delete(dir, true);
        }
        catch
        {
            // Ignore
        }

        _simpleCache?.Release();
        _simpleCache = null;
    }
}