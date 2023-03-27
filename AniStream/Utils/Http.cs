using System;
using System.Net.Http;
using Xamarin.Android.Net;

namespace AniStream.Utils;

internal static class Http
{
    public static Func<HttpClient> ClientProvider => () =>
    {
        var handler = new AndroidMessageHandler();

        var httpClient = new HttpClient(handler, true);

        if (!httpClient.DefaultRequestHeaders.Contains("User-Agent"))
        {
            httpClient.DefaultRequestHeaders.Add(
                "User-Agent",
                Httpz.Utils.Http.ChromeUserAgent()
            );
        }

        return httpClient;
    };
}