using System;
using System.Threading;
using Microsoft.Extensions.Logging;

namespace AniStream.Services;

public class DownloadCenter
{
    private static readonly Lazy<IDownloadService> implementation = new(CreateDownloadService, LazyThreadSafetyMode.PublicationOnly);

    private static IDownloadService CreateDownloadService()
    {
#if NETSTANDARD2_0
            return null;
#else
        return new DownloadServiceImpl();
#endif
    }

    /// <summary>
    /// Internal  Logger
    /// </summary>
    public static ILogger Logger { get; set; } = default!;

    /// <summary>
    /// Platform specific IDownloadService.
    /// </summary>
    public static IDownloadService Current
    {
        get
        {
            var ret = implementation.Value;
            if (ret is null)
                throw new NotImplementedException("Plugin not found");
            return ret;
        }
    }
}