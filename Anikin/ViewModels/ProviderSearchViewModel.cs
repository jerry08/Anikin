using System;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Utils;
using Anikin.ViewModels.Framework;
using Berry.Maui.Controls;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Anime;
using Juro.Core.Providers;

namespace Anikin.ViewModels;

public partial class ProviderSearchViewModel : CollectionViewModel<IAnimeInfo>
{
    private readonly IAnimeProvider? _provider = ProviderResolver.GetAnimeProvider();
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
    async Task ItemSelected(IAnimeInfo item)
    {
        await _bottomSheet.DismissAsync();
        await _episodeViewModel.LoadEpisodes(item);
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
