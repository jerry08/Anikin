using Java.IO;
using Android.Content;
using Com.Google.Android.Exoplayer2.Database;
using Com.Google.Android.Exoplayer2.Upstream;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using Com.Google.Android.Exoplayer2.Util;

namespace AniStream.Utils
{
    public class CacheDataSourceFactory : Java.Lang.Object, IDataSource.IFactory
    {
        public static SimpleCache simpleCache;
        private readonly Context _context;
        private DefaultDataSourceFactory defaultDatasourceFactory;
        private long maxFileSize, maxCacheSize;

        public CacheDataSourceFactory(Context context, long maxCacheSize, long maxFileSize,
            DefaultHttpDataSource.Factory httpDataSourceFactory = null)
        {
            _context = context;
            this.maxCacheSize = maxCacheSize;
            this.maxFileSize = maxFileSize;
            var userAgent = Util.GetUserAgent(context, context.GetString(Resource.String.app_name));
            //DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
            var bandwidthMeter = new DefaultBandwidthMeter.Builder(context).Build();

            defaultDatasourceFactory = new DefaultDataSourceFactory(_context, bandwidthMeter,
                httpDataSourceFactory ?? new DefaultHttpDataSource.Factory()
                    .SetUserAgent(userAgent).SetTransferListener(bandwidthMeter));
        }

        //[Obsolete]
        public IDataSource CreateDataSource()
        {
            if (simpleCache is null)
            {
                //var evictor = new LeastRecentlyUsedCacheEvictor(maxCacheSize);
                var evictor = new NoOpCacheEvictor();
                //SimpleCache simpleCache = new SimpleCache(new File(context.CacheDir, "media"), evictor);
                
                //var databaseProvider = new ExoDatabaseProvider(_context);
                var databaseProvider = new StandaloneDatabaseProvider(_context);

                simpleCache = new SimpleCache(new File(_context.CacheDir, "media"), evictor, databaseProvider);
            }

            //var tt = new CacheDataSource.Factory();
            ////tt.SetCacheReadDataSourceFactory();
            //tt.SetCache(simpleCache);

            return new CacheDataSource(simpleCache, defaultDatasourceFactory.CreateDataSource(),
                    new FileDataSource(), new CacheDataSink(simpleCache, maxFileSize),
                    CacheDataSource.FlagBlockOnCache | CacheDataSource.FlagIgnoreCacheOnError, null);
        }
    }
}