using Microsoft.Maui.Devices;

namespace Anikin.Views.BottomSheets;

public partial class ChangeSourceSheet
{
    public ChangeSourceSheet()
    {
        InitializeComponent();

        Shown += (_, _) => DeviceDisplay.Current.MainDisplayInfoChanged += OnMainDisplayInfoChanged;

        Dismissed += (_, _) =>
            DeviceDisplay.Current.MainDisplayInfoChanged -= OnMainDisplayInfoChanged;
    }

    private void OnMainDisplayInfoChanged(object? sender, DisplayInfoChangedEventArgs e)
    {
        if (e.DisplayInfo.Orientation == DisplayOrientation.Landscape)
        {
            SelectedDetent = Detents[1];
        }
    }
}
