using Microsoft.Maui.Controls;

namespace AniStream.Views;

public partial class AnimeItemView
{
    public AnimeItemView()
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
