using Microsoft.Maui.Controls;

namespace Anikin.Views.Templates.Manga;

public partial class ItemRangeTemplateView
{
    public ItemRangeTemplateView()
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
