using Microsoft.Maui.Controls;

namespace Anikin.Views.Templates;

public partial class GenreTemplateView
{
    public GenreTemplateView()
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
