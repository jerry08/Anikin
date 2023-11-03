using Microsoft.Maui.Controls;
using Berry.Maui.Controls;

namespace AniStream.Views.BottomSheets;

public class BaseBottomSheetView : BottomSheet
{
    private bool BackPressedOnced { get; set; }

    public BaseBottomSheetView()
    {
        Shown += (_, _) => Shell.Current.Navigating += OnShellNavigating;
        Dismissed += (_, _) => Shell.Current.Navigating -= OnShellNavigating;
    }

    private void OnShellNavigating(object? sender, ShellNavigatingEventArgs e)
    {
        if (BackPressedOnced)
            return;

        BackPressedOnced = true;

        DismissAsync();
        e.Cancel();
    }
}
