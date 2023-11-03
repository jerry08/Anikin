using Microsoft.Maui.Devices;

namespace AniStream.Views.BottomSheets;

public partial class EpisodeSelectionSheet
{
    public EpisodeSelectionSheet()
    {
        InitializeComponent();

        Shown += (_, _) => DeviceDisplay.Current.MainDisplayInfoChanged += OnMainDisplayInfoChanged;

        Dismissed += (_, _) =>
            DeviceDisplay.Current.MainDisplayInfoChanged -= OnMainDisplayInfoChanged;

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
