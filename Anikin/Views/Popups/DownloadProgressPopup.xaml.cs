using Anikin.ViewModels.Popups;

namespace Anikin.Views.Popups;

public partial class DownloadProgressPopup
{
    public DownloadProgressPopup(DownloadProgressPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

        WidthRequest = 370;
        HeightRequest = 220;

        viewModel.OnClose += async result =>
            await CloseAsync(result, System.Threading.CancellationToken.None);
    }
}
