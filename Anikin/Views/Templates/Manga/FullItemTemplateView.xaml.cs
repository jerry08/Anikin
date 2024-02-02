using Microsoft.Maui.Controls;

namespace Anikin.Views.Templates.Manga;

public partial class FullItemTemplateView
{
    public FullItemTemplateView()
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
