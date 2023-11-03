using Microsoft.Maui.Controls;

namespace AniStream.Views.Templates;

public partial class EpisodeRangeTemplateView
{
    public EpisodeRangeTemplateView()
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
