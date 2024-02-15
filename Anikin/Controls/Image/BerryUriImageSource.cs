using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Berry.Maui.Extensions;
using Microsoft.Maui.Controls;
using UriTypeConverter = Microsoft.Maui.Controls.UriTypeConverter;

namespace Anikin.Controls;

public class BerryUriImageSource : StreamImageSource
{
    /// <summary>Bindable property for <see cref="Uri"/>.</summary>
    public static readonly BindableProperty UriProperty = BindableProperty.Create(
        nameof(Uri),
        typeof(Uri),
        typeof(BerryUriImageSource),
        default(Uri),
        propertyChanged: (bindable, oldvalue, newvalue) =>
            ((BerryUriImageSource)bindable).OnSourceChanged(),
        validateValue: (bindable, value) => value == null || ((Uri)value).IsAbsoluteUri
    );

    public static readonly BindableProperty HeadersProperty = BindableProperty.Create(
        nameof(Headers),
        typeof(IDictionary<string, string?>),
        typeof(BerryUriImageSource),
        default(IDictionary<string, string?>),
        propertyChanged: (bindable, oldvalue, newvalue) =>
            ((BerryUriImageSource)bindable).OnSourceChanged()
    );

    /// <include file="../../docs/Microsoft.Maui.Controls/UriImageSource.xml" path="//Member[@MemberName='Uri']/Docs/*" />
    [System.ComponentModel.TypeConverter(typeof(UriTypeConverter))]
    public Uri Uri
    {
        get => (Uri)GetValue(UriProperty);
        set => SetValue(UriProperty, value);
    }

    public IDictionary<string, string?> Headers
    {
        get => (IDictionary<string, string?>)GetValue(HeadersProperty);
        set => SetValue(HeadersProperty, value);
    }

    public override Func<CancellationToken, Task<Stream?>> Stream => GetStream;

    private async Task<Stream?> GetStream(CancellationToken cancellationToken)
    {
        try
        {
            using var client = new HttpClient();

            if (Headers is not null)
            {
                foreach (var (key, value) in Headers)
                {
                    client.DefaultRequestHeaders.TryAddWithoutValidation(key, value);
                }
            }

            // Do not remove this await otherwise the client will dispose before
            // the stream even starts
            return await StreamWrapper
                .GetStreamAsync(Uri, cancellationToken, client)
                .ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            //Application
            //    .Current?.FindMauiContext()
            //    ?.CreateLogger<CustomUriImageSource>()
            //    ?.LogWarning(ex, "Error getting stream for {Uri}", Uri);
            return null;
        }
    }
}
