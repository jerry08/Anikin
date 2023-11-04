using AniStream.ViewModels;
using Microsoft.Maui.Devices;

namespace AniStream.Views.BottomSheets;

public partial class VideoSourceSheet
{
    public VideoSourceSheet()
    {
        InitializeComponent();

        Shown += (_, _) => DeviceDisplay.Current.MainDisplayInfoChanged += OnMainDisplayInfoChanged;

        Dismissed += (_, _) =>
        {
            DeviceDisplay.Current.MainDisplayInfoChanged -= OnMainDisplayInfoChanged;

            if (BindingContext is VideoSourceViewModel viewModel)
            {
                viewModel.Cancel();
            }
        };

        //this.UpdateChildrenLayout();
    }

    private void OnMainDisplayInfoChanged(object? sender, DisplayInfoChangedEventArgs e)
    {
        if (e.DisplayInfo.Orientation == DisplayOrientation.Landscape)
        {
            SelectedDetent = Detents[1];
        }
    }
}
