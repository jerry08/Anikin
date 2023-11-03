using System;
using System.Threading.Tasks;
using AniStream.Utils;
using AniStream.ViewModels.Framework;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Anime;
using Juro.Core.Providers;
using Berry.Maui.Controls;

namespace AniStream.ViewModels;

public partial class ProviderSearchViewModel : CollectionViewModel<IAnimeInfo>
{
    private readonly IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();
    private readonly BottomSheet _bottomSheet;
    private readonly EpisodeViewModel _episodeViewModel;

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

        if (!await IsOnline())
            return;

        if (!IsRefreshing)
            IsBusy = true;

        try
        {
            var result = await _provider.SearchAsync(Query);
            Push(result);
            Offset += result.Count;
        }
        catch (Exception ex)
        {
            await App.AlertService.ShowAlertAsync("Error", ex.ToString());
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
}
