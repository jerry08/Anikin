using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AniStream.Utils.Extensions;

public static class DictionaryExtensions
{
    public static NameValueCollection ToNameValueCollection<TKey, TValue>(
        this IDictionary<TKey, TValue> dict)
    {
        var nameValueCollection = new NameValueCollection();

        foreach (var kvp in dict)
        {
            string value = null;
            if (kvp.Value != null)
                value = kvp.Value.ToString();

            nameValueCollection.Add(kvp.Key.ToString(), value);
        }

        return nameValueCollection;
    }
}