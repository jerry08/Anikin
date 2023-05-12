using System.Collections.Generic;
using Android.Runtime;

namespace AniStream.Utils.Extensions;

public static class JavaExtensions
{
    public static Dictionary<string, string?> ToDictionary(this JavaDictionary javaDictionary)
    {
        var dict = new Dictionary<string, string?>();

        foreach (var key in javaDictionary.Keys)
        {
            dict.Add(key.ToString()!, javaDictionary[key]?.ToString());
        }

        return dict;
    }
}