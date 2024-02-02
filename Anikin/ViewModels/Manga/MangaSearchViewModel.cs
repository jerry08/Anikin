using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Parameters;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels.Manga;

public partial class MangaSearchViewModel : CollectionViewModel<Jita.AniList.Models.Media>
{
    private readonly AniClient _anilistClient;
    private readonly SettingsService _settingsService;

    private CancellationTokenSource CancellationTokenSource = new();

    public CancellationToken CancellationToken => CancellationTokenSource.Token;

    private int PageIndex { get; set; } = 1;
    private int PageSize { get; set; } = 50;

    public MangaSearchViewModel(AniClient aniClient, SettingsService settingsService)
    {
        _anilistClient = aniClient;
        _settingsService = settingsService;

        _settingsService.Load();

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

        if (!IsLoading)
        {
            PageIndex = 1;
        }
        else
        {
            if (IsRefreshing)
                IsBusy = true;
        }

        try
        {
            Offset = 0;

            CancellationTokenSource.Cancel();
            CancellationTokenSource = new();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Query = Query,
                    IsAdult = false,
                    Sort = Jita.AniList.Models.MediaSort.Popularity,
                    Type = Jita.AniList.Models.MediaType.Anime
                },
                new AniPaginationOptions(PageIndex, PageSize),
                CancellationTokenSource.Token
            );

            if (result.Data.Length == 0)
            {
                Offset = -1;
                return;
            }

            PageIndex++;

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            Push(data);
        }
        catch (Exception ex)
        {
            if (ex is OperationCanceledException) { }
            else
            {
                await App.AlertService.ShowAlertAsync("Error", ex.ToString());
            }
        }
        finally
        {
            IsBusy = false;
            IsLoading = false;
            IsRefreshing = false;
        }
    }

    public override bool CanLoadMore() => !IsLoading && Offset >= 0;

    [RelayCommand]
    async Task ItemSelected(Jita.AniList.Models.Media item)
    {
        var navigationParameter = new Dictionary<string, object> { { "SourceItem", item } };

        await Shell.Current.GoToAsync(nameof(EpisodePage), navigationParameter);
    }
}
