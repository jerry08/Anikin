using Microsoft.Maui.Controls;

namespace Anikin.Views;

public partial class ProviderMangaItemView
{
    public ProviderMangaItemView()
    {
        InitializeComponent();
    }

    protected override void OnBindingContextChanged()
    {
        base.OnBindingContextChanged();

        Scale = 0.4;
        this.ScaleToAsync(1, 150);
    }
}
