using Microsoft.Maui.Controls;

namespace AniStream.Views;

public partial class ProviderAnimeItemView
{
    public ProviderAnimeItemView()
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
