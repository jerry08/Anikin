using Microsoft.Maui.Controls;

namespace Anikin.Views;

public partial class MangaItemView
{
    public MangaItemView()
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
