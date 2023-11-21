using Anikin.ViewModels.Popups;

namespace Anikin.Views.Popups;

public partial class LoadingPopup
{
    public LoadingPopup(LoadingPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
