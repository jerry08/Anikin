using System.Collections.Generic;
using System.Threading.Tasks;

namespace AniStream.Services;

public interface IDownloadService
{
    Task EnqueueAsync(string fileName, string url, IDictionary<string, string>? headers = null);
}
