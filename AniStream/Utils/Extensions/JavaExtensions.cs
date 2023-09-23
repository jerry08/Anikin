using System.Collections.Generic;
using Android.Runtime;

namespace AniStream.Utils.Extensions;

public static class JavaExtensions
{
    public static Dictionary<string, string?> ToDictionary(this JavaDictionary javaDictionary)
    {
        var dictionary = new Dictionary<string, string?>();

        foreach (var key in javaDictionary.Keys)
        {
            var keyStr = key?.ToString();

            if (!string.IsNullOrWhiteSpace(keyStr))
            {
                dictionary.Add(keyStr, javaDictionary[keyStr]?.ToString());
            }
        }

        return dictionary;
    }
}