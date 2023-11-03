using AniStream.Utils;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui.Controls;

namespace AniStream.ViewModels.Framework;

public partial class CollectionViewModelBase : BaseViewModel
{
    [ObservableProperty]
    private string? _query;

    public string? PreviousQuery { get; set; }

    /// <summary>
    /// True if viewmodel is loading more records
    /// </summary>
    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private SelectionMode _selectionMode;

    [ObservableProperty]
    private int _offset;

    public ObservableRangeCollection<object> SelectedEntities { get; } = new();

    [ObservableProperty]
    private bool _isSelectAllChecked;

    [ObservableProperty]
    private object? _selectedEntity;

    public CollectionViewModelBase()
    {
        IsBusy = true;
        SelectionMode = SelectionMode.None;
    }

    public virtual bool CanLoadMore() => true;

    [RelayCommand]
    void EnableMultiSelect()
    {
        SelectionMode = SelectionMode.Multiple;
    }

    [RelayCommand]
    //void EnableMultiSelectWithParameter(T selectedItem)
    void EnableMultiSelectWithParameter(object selectedItem)
    {
        SelectionMode = SelectionMode.Multiple;

        SelectedEntity = selectedItem;

        if (!SelectedEntities.Contains(selectedItem))
            SelectedEntities.Add(selectedItem);
    }
}
