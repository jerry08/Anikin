using System.Collections.Generic;
using System.Linq;

namespace AniStream.Utils.Extensions;

public static class ObservableRangeCollectionExtensions
{
    /// <summary>
    /// Adds or replaces items.
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="source"></param>
    /// <param name="items"></param>
    /// <param name="replaceItems"></param>
    public static void Push<T>(
        this ObservableRangeCollection<T> source,
        IEnumerable<T> items,
        bool replaceItems = false
    )
    {
        // Convert to list to prevent multi-select bugs
        var list = items.ToList();

        if (replaceItems)
        {
            source.ReplaceRange(list);
        }
        else
        {
            source.Clear();
            source.AddRange(list);
        }
    }
}
