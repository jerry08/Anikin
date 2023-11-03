using System.Collections.Generic;
using System.Threading.Tasks;

namespace AniStream.Services;

public class DownloadServiceImpl : IDownloadService
{
    public static DownloadServiceImpl Create() => new();

    public async Task EnqueueAsync(
        string fileName,
        string url,
        IDictionary<string, string>? headers = null
    ) { }
}
