using System;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using Berry.Maui.Controls;
using CommunityToolkit.Mvvm.Input;
using Juro.Clients;
using Juro.Core.Models.Anime;

namespace Anikin.ViewModels;

public partial class ProviderSearchViewModel : CollectionViewModel<IAnimeInfo>
{
    private readonly SettingsService _settingsService = new();

    private readonly AnimeApiClient _apiClient = new(Constants.ApiEndpoint);
    private readonly BottomSheet _bottomSheet;
    private readonly EpisodeViewModel _episodeViewModel;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    public ProviderSearchViewModel(
        EpisodeViewModel episodeViewModel,
        BottomSheet bottomSheet,
        string query
    )
    {
        _episodeViewModel = episodeViewModel;
        _bottomSheet = bottomSheet;
        Query = query;

        _settingsService.Load();

        _apiClient.ProviderKey = _settingsService.LastProviderKey!;

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
    async Task ItemSelected(IAnimeInfo item)
    {
        await _bottomSheet.DismissAsync();
        await _episodeViewModel.LoadEpisodes(item);
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
