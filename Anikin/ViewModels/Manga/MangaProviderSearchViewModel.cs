using System;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Utils;
using Anikin.ViewModels.Framework;
using Anikin.ViewModels.Manga;
using Berry.Maui.Controls;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Manga;
using Juro.Core.Providers;

namespace Anikin.ViewModels.Manga;

public partial class MangaProviderSearchViewModel : CollectionViewModel<IMangaResult>
{
    private readonly IMangaProvider? _provider = ProviderResolver.GetMangaProvider();
    private readonly MangaItemViewModel _mangaItemViewModel;
    private readonly BottomSheet _bottomSheet;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    public MangaProviderSearchViewModel(
        MangaItemViewModel mangaItemViewModel,
        BottomSheet bottomSheet,
        string query
    )
    {
        _mangaItemViewModel = mangaItemViewModel;
        _bottomSheet = bottomSheet;
        Query = query;

        Load();
    }

    protected override async Task LoadCore()
    {
        if (string.IsNullOrWhiteSpace(Query))
        {
            IsRefreshing = false;
            IsBusy = false;
            Entities.Clear();
            return;
        }

        if (_provider is null)
        {
            await Toast.Make("No providers installed").Show();
            return;
        }

        if (!await IsOnline())
            return;

        if (!IsRefreshing)
            IsBusy = true;

        try
        {
            var result = await _provider.SearchAsync(Query, CancellationToken);
            Push(result);
            Offset += result.Count;
        }
        catch (Exception ex)
        {
            if (!CancellationToken.IsCancellationRequested)
            {
                await App.AlertService.ShowAlertAsync("Error", ex.ToString());
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
    }

    [RelayCommand]
    async Task ItemSelected(IMangaResult item)
    {
        await _bottomSheet.DismissAsync();
        await _mangaItemViewModel.LoadChapters(item);
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
