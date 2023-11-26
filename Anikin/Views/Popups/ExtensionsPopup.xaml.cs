using System;
using Anikin.ViewModels.Popups;

namespace Anikin.Views.Popups;

public partial class ExtensionsPopup
{
    public ExtensionsPopup(ExtensionsPopupViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;

        Size = new Microsoft.Maui.Graphics.Size(380, 280);
    }

    private void CancelButton_Clicked(object sender, EventArgs e) => CloseAsync(false);

    private void SaveButton_Clicked(object sender, EventArgs e) => CloseAsync(true);
}
