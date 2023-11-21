using Anikin.ViewModels.Popups;

namespace Anikin.Views.Popups;

public partial class ExtensionsPopup
{
    public ExtensionsPopup(ExtensionsPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

        Size = new Microsoft.Maui.Graphics.Size(400, 300);
    }
}
