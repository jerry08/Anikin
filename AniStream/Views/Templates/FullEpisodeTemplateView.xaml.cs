using Microsoft.Maui.Controls;

namespace AniStream.Views.Templates;

public partial class FullEpisodeTemplateView
{
    public FullEpisodeTemplateView()
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