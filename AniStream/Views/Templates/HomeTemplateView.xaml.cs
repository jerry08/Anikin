using System.Threading.Tasks;

namespace AniStream.Views.Templates;

public partial class HomeTemplateView
{
    public HomeTemplateView()
    {
        InitializeComponent();

        img1.Loaded += delegate
        {
            img1.IsAnimationPlaying = false;

            Task.Run(async () =>
            {
                await Task.Delay(500);
                img1.IsAnimationPlaying = true;
            });
        };
    }
}
