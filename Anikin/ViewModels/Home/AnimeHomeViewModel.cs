using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Jita.AniList.Parameters;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels.Home;

public partial class AnimeHomeViewModel : BaseViewModel
{
    private readonly AniClient _anilistClient;
    private readonly SettingsService _settingsService;

    public ObservableRangeCollection<Media> CurrentSeasonMedias { get; set; } = [];
    public ObservableRangeCollection<Media> PopularMedias { get; set; } = [];
    public ObservableRangeCollection<Media> LastUpdatedMedias { get; set; } = [];

    public ObservableRangeCollection<AnimeHomeRange> Ranges { get; set; } = [];

    [ObservableProperty]
    AnimeHomeRange _selectedRange;

    public AnimeHomeViewModel(AniClient anilistClient, SettingsService settingsService)
    {
        _anilistClient = anilistClient;
        _settingsService = settingsService;

        _settingsService.Load();

        //Load();

        var homeTypes = Enum.GetValues(typeof(AnimeHomeTypes)).Cast<AnimeHomeTypes>();
        Ranges.AddRange(homeTypes.Select(x => new AnimeHomeRange(x)));
        Ranges[0].IsSelected = true;

        SelectedRange = Ranges[0];
    }

    protected override async Task LoadCore()
    {
        if (!await IsOnline())
            return;

        if (!IsRefreshing)
            IsBusy = true;

        RangeSelected(SelectedRange);

        try
        {
            LoadPopular();
            LoadLastUpdated();
            LoadCurrentSeason();
            //LoadTrending();
            //LoadNewSeason();
            //LoadFeminineMedia();
            //LoadMaleMedia();
            //LoadTrashMedia();

            //var pages2 = await _anilistClient.GetTrendingMediaAsync();
            //var schedulesResult = await _anilistClient.GetMediaSchedulesAsync(
            //    new MediaSchedulesFilter
            //    {
            //        StartedAfterDate = DateTime.Now,
            //        EndedBeforeDate = DateTime.Now.AddDays(7)
            //    }
            //);
            //
            //var result2 = schedulesResult.Data
            //    .Where(x => x.Media is not null)
            //    .Select(x => x.Media!)
            //    .ToList();
            //
            //LastUpdatedMedias.Clear();
            //LastUpdatedMedias.Push(result2);
        }
        catch (Exception ex)
        {
            await App.AlertService.ShowAlertAsync("Error", ex.ToString());
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
            //IsLoading = false;
        }
    }

    [RelayCommand]
    async Task Refresh()
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

        await LoadCore();
    }

    [RelayCommand]
    //async Task ItemSelected(IAnimeInfo item)
    async Task ItemSelected(Media item)
    {
        var navigationParameter = new Dictionary<string, object> { { "SourceItem", item } };

        await Shell.Current.GoToAsync(nameof(EpisodePage), navigationParameter);
    }

    [RelayCommand]
    async Task GoToSearch()
    {
        await Shell.Current.GoToAsync(nameof(SearchView));
    }

    [RelayCommand]
    void RangeSelected(AnimeHomeRange range)
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        range.IsSelected = true;

        SelectedRange = range;

        switch (range.Type)
        {
            case AnimeHomeTypes.Popular:
                break;
            case AnimeHomeTypes.LastUpdated:
                break;
            case AnimeHomeTypes.CurrentSeason:
                break;
            case AnimeHomeTypes.Trending:
                LoadTrending();
                break;
            case AnimeHomeTypes.NewSeason:
                LoadNewSeason();
                break;
            case AnimeHomeTypes.FeminineMedia:
                LoadFeminineMedia();
                break;
            case AnimeHomeTypes.MaleMedia:
                LoadMaleMedia();
                break;
            case AnimeHomeTypes.TrashMedia:
                LoadTrashMedia();
                break;
        }
    }

    private async void LoadMaleMedia()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.MaleMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shounen"] = true },
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Popularity,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadFeminineMedia()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.FeminineMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shoujo"] = true },
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Popularity,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadTrashMedia()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.TrashMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Favorites,
                    SortDescending = false,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadNewSeason()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.NewSeason);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter { Season = MediaSeason.Winter }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadLastUpdated()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.LastUpdated);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var recentlyUpdateResult = await _anilistClient.GetMediaSchedulesAsync(
                new MediaSchedulesFilter
                {
                    StartedAfterDate = DateTime.Now.AddDays(-7),
                    EndedBeforeDate = DateTime.Now,
                    NotYetAired = false,
                    Sort = MediaScheduleSort.Time,
                    SortDescending = true,
                },
                new AniPaginationOptions(1, 50)
            );

            var data = recentlyUpdateResult
                .Data.Where(x =>
                    x.Media is not null
                    && !x.Media.IsAdult
                    && (_settingsService.ShowNonJapaneseAnime || x.Media.CountryOfOrigin == "JP")
                )
                .Select(x => x.Media!)
                .GroupBy(x => x.Id)
                .Select(x => x.First())
                .ToList();

            LastUpdatedMedias.Clear();
            LastUpdatedMedias.Push(data);

            rangeItem.Medias.Clear();
            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadTrending()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.Trending);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.GetTrendingMediaAsync(
                new MediaTrendFilter() { Sort = MediaTrendSort.Popularity },
                new AniPaginationOptions()
            );

            var data = result
                .Data.Where(x =>
                    x.Media is not null
                    && (_settingsService.ShowNonJapaneseAnime || x.Media.CountryOfOrigin == "JP")
                )
                .Select(x => x.Media!)
                .ToList();

            rangeItem.Medias.Clear();
            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadCurrentSeason()
    {
        var currentMediaSeason = DateTime.Now.Month switch
        {
            1 or 2 or 3 => MediaSeason.Winter,
            4 or 5 or 6 => MediaSeason.Spring,
            7 or 8 or 9 => MediaSeason.Summer,
            10 or 11 or 12 => MediaSeason.Fall,
            _ => MediaSeason.Winter,
        };

        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.CurrentSeason);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Anime,
                    Sort = MediaSort.Popularity,
                    Season = currentMediaSeason,
                    IsAdult = false,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            CurrentSeasonMedias.Clear();
            CurrentSeasonMedias.Push(data);

            rangeItem.Medias.Clear();
            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }

    private async void LoadPopular()
    {
        var rangeItem = Ranges.First(x => x.Type == AnimeHomeTypes.Popular);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            //var result = await _anilistClient.SearchMediaAsync(new SearchMediaFilter()
            //{
            //    Query = "demon slayer",
            //    Type = MediaType.Anime,
            //});

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Anime,
                    Sort = MediaSort.Popularity,
                    IsAdult = false,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            PopularMedias.Clear();
            PopularMedias.Push(data);

            rangeItem.Medias.Clear();
            rangeItem.Medias.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            rangeItem.IsLoading = false;
        }
    }
}
