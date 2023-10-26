using Berry.Maui;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Devices;

namespace AniStream.Views.BottomSheets;

public partial class ProviderSearchSheet
{
    private const int ItemWidth = 180;

    private DisplayOrientation LastDisplayOrientation { get; set; }

    public ProviderSearchSheet()
    {
        InitializeComponent();

        Shown += (_, _) =>
        {
            SearchEntry.Focused += SearchEntry_Focused;
            SearchEntry.Completed += SearchEntry_Completed;
        };

        Dismissed += (_, _) =>
        {
            SearchEntry.Focused -= SearchEntry_Focused;
            SearchEntry.Completed -= SearchEntry_Completed;
        };

        var statusBarHeight = ApplicationEx.GetStatusBarHeight() / DeviceDisplay.MainDisplayInfo.Density;
        MainGrid.Margin = new Thickness(5, statusBarHeight + 10, 5, 0);

        SizeChanged += (_, _) =>
        {
            //var columns = 1 + (int)(Width / ItemWidth);
            var columns = 1 + (int)((MainGrid.Width - (MainGrid.Margin.Left + MainGrid.Margin.Right)) / ItemWidth);

            // Fix Maui bug where margins are reducing view when rotating device from
            // Portrait to Landscape then back to Portrait
            if (LastDisplayOrientation != DeviceDisplay.Current.MainDisplayInfo.Orientation)
            {
                LastDisplayOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation;
                SearchCollectionView.ItemsLayout = new GridItemsLayout(columns, ItemsLayoutOrientation.Vertical);
            }
            else
            {
                (SearchCollectionView.ItemsLayout as GridItemsLayout)!.Span = columns;
            }
        };
    }

    private bool IsEntryCompleted = true;

    private void SearchEntry_Completed(object? sender, System.EventArgs e)
    {
        IsEntryCompleted = true;
    }

    private void SearchEntry_Focused(object? sender, FocusEventArgs e)
    {
        SelectedDetent = Detents[1];

        if (IsEntryCompleted)
        {
            Dispatcher.Dispatch(() =>
            {
                SearchEntry.CursorPosition = 0;
                SearchEntry.SelectionLength = (SearchEntry.Text?.Length) ?? 0;
            });
        }

        //Dispatcher.Dispatch(() =>
        //{
        //    // Highlight all text when a user clicks the entry while the keyboard is not showing
        //    if (!SearchEntry.IsSoftKeyboardShowing())
        //    {
        //        SearchEntry.CursorPosition = 0;
        //        SearchEntry.SelectionLength = (SearchEntry.Text?.Length) ?? 0;
        //
        //        SelectedDetent = Detents[1];
        //    }
        //});

        IsEntryCompleted = false;
    }
}
