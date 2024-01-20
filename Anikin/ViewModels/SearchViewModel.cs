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

namespace Anikin.ViewModels;

public partial class SearchViewModel : CollectionViewModel<Jita.AniList.Models.Media>
{
    private readonly AniClient _anilistClient;
    private readonly SettingsService _settingsService;

    private CancellationTokenSource CancellationTokenSource = new();

    public CancellationToken CancellationToken => CancellationTokenSource.Token;

    private int PageIndex { get; set; } = 1;
    private int PageSize { get; set; } = 50;

    public SearchViewModel(AniClient aniClient, SettingsService settingsService)
    {
        _anilistClient = aniClient;
        _settingsService = settingsService;

        _settingsService.Load();

        //PropertyChanging += async (s, e) =>
        //{
        //    if (e.PropertyName == nameof(Query))
        //        await QueryChanged();
        //};

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

        //var canc = new CancellationTokenSource();
        //
        ////var _client = new AniClient();
        //
        //for (var i = 0; i < 10; i++)
        //{
        //    Task.Run(async () =>
        //    {
        //        canc.Cancel();
        //        canc = new();
        //
        //        try
        //        {
        //            var pages4 = await _anilistClient.GetMediaSchedulesAsync(
        //            new MediaSchedulesFilter
        //            {
        //                StartedAfterDate = DateTime.Now.AddDays(-7),
        //                EndedBeforeDate = DateTime.Now,
        //                NotYetAired = false
        //            },
        //            null,
        //            canc.Token
        //        );
        //        }
        //        catch (Exception ee)
        //        {
        //            if (ee is not OperationCanceledException)
        //            {
        //
        //            }
        //        }
        //
        //    });
        //}
        //
        //await Task.Delay(4000);

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
                //await App.AlertService.ShowAlertAsync(
                //    "Nothing found",
                //    "Couldn't find any media based on the query you provided"
                //);
                return;
            }

            PageIndex++;

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            Push(data);
            //Offset += data.Count;
        }
        catch (Exception ex)
        {
            if (ex is OperationCanceledException) { }
            //else if (ex is WebSocketException webSocketException)
            //else if (ex is WebException webException)
            //{
            //
            //}
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

    //public override bool CanLoadMore() => Offset % PageSize == 0;
    public override bool CanLoadMore() => !IsLoading && Offset >= 0;

    [RelayCommand]
    async Task ItemSelected(Jita.AniList.Models.Media item)
    {
        var navigationParameter = new Dictionary<string, object> { { "SourceItem", item } };

        await Shell.Current.GoToAsync(nameof(EpisodePage), navigationParameter);
    }
}
