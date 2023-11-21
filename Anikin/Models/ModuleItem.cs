using Juro;

namespace Anikin.Models;

public class ModuleItem
{
    public string? Name { get; set; }

    public string? Language { get; set; }

    public string? LanguageDisplayName { get; set; }

    public Module Module { get; set; } = default!;
}
