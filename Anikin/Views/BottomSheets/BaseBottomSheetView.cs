using Anikin.Models;
using Berry.Maui.Controls;
using Microsoft.Maui.Controls;

namespace Anikin.Views.BottomSheets;

public class BaseBottomSheetView : BottomSheet
{
    private bool BackPressedOnced { get; set; }

    public BaseBottomSheetView()
    {
        Shown += (_, _) =>
        {
            AppShell.BackButtonPressed += AppShell_BackButtonPressed;
            //Shell.Current.Navigating += OnShellNavigating;
        };

        Dismissed += (_, _) =>
        {
            AppShell.BackButtonPressed -= AppShell_BackButtonPressed;
            //Shell.Current.Navigating -= OnShellNavigating;
        };
    }

    private void AppShell_BackButtonPressed(object? sender, BackPressedEventArgs e)
    {
        if (BackPressedOnced)
            return;

        BackPressedOnced = true;

        DismissAsync();
        e.Cancel();
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
