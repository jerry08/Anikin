namespace Anikin.Models;

public class ProviderModel
{
    public string Key { get; set; } = default!;

    public string Name { get; set; } = default!;

    public string Language { get; set; } = default!;

    public string LanguageDisplayName { get; set; } = default!;

    public bool IsSelected { get; set; }
}
