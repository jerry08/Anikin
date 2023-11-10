using System.Threading.Tasks;
using Microsoft.Maui.Devices;

namespace Anikin.Views.Templates;

public partial class AnimeCarouselTemplateView
{
    public AnimeCarouselTemplateView()
    {
        InitializeComponent();

        //img1.Loaded += delegate
        //{
        //    img1.IsAnimationPlaying = false;
        //
        //    Task.Run(async () =>
        //    {
        //        await Task.Delay(200);
        //        img1.IsAnimationPlaying = true;
        //    });
        //};

        //WidthRequest = DeviceDisplay.MainDisplayInfo.Width / DeviceDisplay.MainDisplayInfo.Density;
        //
        //SizeChanged += (_, _) =>
        //    WidthRequest =
        //        DeviceDisplay.MainDisplayInfo.Width / DeviceDisplay.MainDisplayInfo.Density;
    }
}
