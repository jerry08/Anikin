using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using Com.Google.Android.Exoplayer2.Database;
using Com.Google.Android.Exoplayer2.Upstream;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using Com.Google.Android.Exoplayer2.Util;
using Java.IO;

namespace AniStream.Utils
{
    public class CacheDataSourceFactory : Java.Lang.Object, IDataSourceFactory
    {
        public static SimpleCache simpleCache;
        private Context context;
        private DefaultDataSourceFactory defaultDatasourceFactory;
        private long maxFileSize, maxCacheSize;

        public CacheDataSourceFactory(Context context, long maxCacheSize, long maxFileSize,
            DefaultHttpDataSourceFactory httpDataSourceFactory = null)
        {
            this.context = context;
            this.maxCacheSize = maxCacheSize;
            this.maxFileSize = maxFileSize;
            string userAgent = Util.GetUserAgent(context, context.GetString(Resource.String.app_name));
            //DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
            DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter
                .Builder(context).Build();
            defaultDatasourceFactory = new DefaultDataSourceFactory(this.context, bandwidthMeter,
                httpDataSourceFactory ?? new DefaultHttpDataSourceFactory(userAgent, bandwidthMeter));
        }

        //[Obsolete]
        public IDataSource CreateDataSource()
        {
            LeastRecentlyUsedCacheEvictor evictor = new LeastRecentlyUsedCacheEvictor(maxCacheSize);
            //SimpleCache simpleCache = new SimpleCache(new File(context.CacheDir, "media"), evictor);
            var databaseProvider = new ExoDatabaseProvider(context);
            
            if (simpleCache == null)
                simpleCache = new SimpleCache(new File(context.CacheDir, "media"), evictor, databaseProvider);
            
            return new CacheDataSource(simpleCache, defaultDatasourceFactory.CreateDataSource(),
                    new FileDataSource(), new CacheDataSink(simpleCache, maxFileSize),
                    CacheDataSource.FlagBlockOnCache | CacheDataSource.FlagIgnoreCacheOnError, null);
        }
    }
}