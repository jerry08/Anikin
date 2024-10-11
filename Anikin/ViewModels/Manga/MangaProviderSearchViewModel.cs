using System;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using Berry.Maui.Controls;
using CommunityToolkit.Mvvm.Input;
using Juro.Clients;
using Juro.Core.Models.Manga;

namespace Anikin.ViewModels.Manga;

public partial class MangaProviderSearchViewModel : CollectionViewModel<IMangaResult>
{
    private readonly SettingsService _settingsService = new();
    private readonly MangaApiClient _apiClient = new(Constants.ApiEndpoint);

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

        _settingsService.Load();

        _apiClient.ProviderKey = _settingsService.LastMangaProviderKey!;

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

        if (!await IsOnline())
            return;

        if (!IsRefreshing)
            IsBusy = true;

        try
        {
            var result = await _apiClient.SearchAsync(Query, CancellationToken);
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
