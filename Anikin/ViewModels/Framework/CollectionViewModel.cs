using System.Collections.Generic;
using System.Threading.Tasks;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using CommunityToolkit.Mvvm.Input;

namespace Anikin.ViewModels.Framework;

public partial class CollectionViewModel<T> : CollectionViewModelBase
    where T : class
{
    public ObservableRangeCollection<T> Entities { get; set; } = [];

    [RelayCommand]
    public virtual void LoadMore()
    {
        if (IsBusy)
            return;

        if (!CanLoadMore())
            return;

        if (Entities.Count == 0)
            return;

        IsLoading = true;
        LoadCore();
    }

    public void Push(IEnumerable<T> entities)
    {
        if (IsLoading)
        {
            Entities.AddRange(entities);
        }
        else
        {
            if (IsRefreshing)
            {
                Entities.Clear();
            }

            Entities.Push(entities);
        }

        IsBusy = false;
        IsRefreshing = false;
        IsLoading = false;

        OnPropertyChanged(nameof(Entities));
    }

    [RelayCommand]
    public virtual async Task Refresh()
    {
        if (IsBusy)
            return;

        if (!await IsOnline())
        {
            IsRefreshing = false;
            return;
        }

        if (!IsRefreshing)
            IsBusy = true;

        Offset = 0;

        await LoadCore();
    }

    [RelayCommand]
    async Task Create()
    {
        if (!await IsOnline())
            return;

        CreateCore();
    }

    protected virtual void CreateCore() { }

    [RelayCommand]
    async Task Edit(T entity)
    {
        if (!await IsOnline())
            return;

        EditCore(entity);
    }

    protected virtual void EditCore(T entity) { }

    [RelayCommand]
    async Task View(T entity)
    {
        if (!await IsOnline())
            return;

        ViewCore(entity);
    }

    protected virtual void ViewCore(T entity) { }

    [RelayCommand]
    async Task Delete(T entity)
    {
        if (!await IsOnline())
            return;

        DeleteCore(entity);
    }

    protected virtual void DeleteCore(T entity) { }

    [RelayCommand]
    public virtual async Task QueryChanged()
    {
        PreviousQuery = Query;

        if (!await IsOnline())
            return;

        IsBusy = true;
        Offset = 0;
        //Entities.Clear();

        Entities.Clear();
        await LoadCore();

        if (string.IsNullOrWhiteSpace(Query))
            Entities.Clear();
    }

    [RelayCommand]
    void SelectionChanged()
    {
        if (Entities.Count == 0)
            return;

        IsSelectAllChecked = SelectedEntities.Count == Entities.Count;
    }

    [RelayCommand]
    void SelectOrUnselectAll()
    {
        if (Entities.Count == 0)
            return;

        if (IsSelectAllChecked)
            SelectedEntities.ReplaceRange(Entities);
        else
            SelectedEntities.Clear();
    }
}
