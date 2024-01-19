using System.Collections.Generic;

namespace Anikin.Models;

public class PluginListGroup<T> : List<T>
{
    public Juro.Plugin Plugin { get; }

    public PluginListGroup(Juro.Plugin plugin, List<T> items)
        : base(items)
    {
        Plugin = plugin;
    }
}
