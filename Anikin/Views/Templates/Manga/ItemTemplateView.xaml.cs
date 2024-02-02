using Microsoft.Maui.Controls;

namespace Anikin.Views.Templates.Manga;

public partial class ItemTemplateView
{
    public ItemTemplateView()
    {
        InitializeComponent();
    }

    protected override void OnBindingContextChanged()
    {
        base.OnBindingContextChanged();

        Scale = 0.4;
        this.ScaleTo(1, 150);
    }
}
