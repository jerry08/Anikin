using Juro;

namespace Anikin.Models;

public class PluginItem
{
    public string? Name { get; set; }

    public string? Language { get; set; }

    public string? LanguageDisplayName { get; set; }

    public Juro.Plugin Plugin { get; set; } = default!;
}
