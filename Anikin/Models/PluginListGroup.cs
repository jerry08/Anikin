using System.Collections.Generic;

namespace Anikin.Models;

public class PluginListGroup<T>(Juro.Plugin plugin, List<T> items) : List<T>(items)
{
    public Juro.Plugin Plugin { get; } = plugin;
}
