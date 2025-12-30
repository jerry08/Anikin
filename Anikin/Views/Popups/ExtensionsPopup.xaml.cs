using System;
using Anikin.ViewModels.Popups;

namespace Anikin.Views.Popups;

public partial class ExtensionsPopup
{
    public ExtensionsPopup(ExtensionsPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    private void CancelButton_Clicked(object sender, EventArgs e) => CloseAsync(false);

    private void SaveButton_Clicked(object sender, EventArgs e) => CloseAsync(true);
}
