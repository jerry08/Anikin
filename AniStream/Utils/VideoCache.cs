using Android.Content;
using Com.Google.Android.Exoplayer2.Database;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using Java.IO;

namespace AniStream.Utils;

internal class VideoCache
{
    private static SimpleCache? _simpleCache = null;

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
                databaseProvider);
        }

        return _simpleCache;
    }

    public static void Release()
    {
        _simpleCache?.Release();
        _simpleCache = null;
    }
}