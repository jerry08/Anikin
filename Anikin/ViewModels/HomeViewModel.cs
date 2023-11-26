using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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

namespace Anikin.ViewModels;

public partial class HomeViewModel : BaseViewModel
{
    private readonly AniClient _anilistClient;
    private readonly SettingsService _settingsService;

    private int Page { get; set; }

    public ObservableRangeCollection<Media> PopularAnimes { get; set; } = new();
    public ObservableRangeCollection<Media> CurrentSeasonAnimes { get; set; } = new();
    public ObservableRangeCollection<Media> TrendingAnimes { get; set; } = new();
    public ObservableRangeCollection<Media> LastUpdatedAnimes { get; set; } = new();
    public ObservableRangeCollection<Media> NewSeasonAnimes { get; set; } = new();
    public ObservableRangeCollection<Media> FeminineMedia { get; set; } = new();
    public ObservableRangeCollection<Media> TrashMedia { get; set; } = new();
    public ObservableRangeCollection<Media> MaleMedia { get; set; } = new();

    [ObservableProperty]
    private int _selectedViewModelIndex;

    public ProfileViewModel ProfileViewModel { get; set; }

    public HomeViewModel(
        AniClient anilistClient,
        ProfileViewModel profileViewModel,
        SettingsService settingsService
    )
    {
        _anilistClient = anilistClient;
        ProfileViewModel = profileViewModel;
        _settingsService = settingsService;

        _settingsService.Load();

        //Load();
    }

    protected override async Task LoadCore()
    {
        if (!await IsOnline())
            return;

        if (!IsRefreshing)
            IsBusy = true;

        try
        {
            LoadPopular();
            LoadCurrentSeason();
            LoadTrending();
            LoadLastUpdated();
            LoadNewSeason();
            LoadFeminineMedia();
            LoadMaleMedia();
            LoadTrashMedia();

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
            //LastUpdatedAnimes.Clear();
            //LastUpdatedAnimes.Push(result2);
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

    private async void LoadMaleMedia()
    {
        try
        {
            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shounen"] = true },
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Popularity
                }
            );

            var data = result
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            MaleMedia.Clear();
            MaleMedia.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadFeminineMedia()
    {
        try
        {
            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shoujo"] = true },
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Popularity
                }
            );

            var data = result
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            FeminineMedia.Clear();
            FeminineMedia.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadTrashMedia()
    {
        try
        {
            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Anime,
                    IsAdult = false,
                    Sort = MediaSort.Favorites,
                    SortDescending = false
                }
            );

            var data = result
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            TrashMedia.Clear();
            TrashMedia.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadNewSeason()
    {
        try
        {
            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter { Season = MediaSeason.Winter }
            );

            var data = result
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            NewSeasonAnimes.Clear();
            NewSeasonAnimes.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadLastUpdated()
    {
        try
        {
            var recentlyUpdateResult = await _anilistClient.GetMediaSchedulesAsync(
                new MediaSchedulesFilter
                {
                    StartedAfterDate = DateTime.Now.AddDays(-7),
                    EndedBeforeDate = DateTime.Now,
                    NotYetAired = false,
                    Sort = MediaScheduleSort.Time,
                    SortDescending = true
                },
                new AniPaginationOptions(1, 50)
            );

            var data = recentlyUpdateResult
                .Data
                .Where(
                    x =>
                        x.Media is not null
                        && !x.Media.IsAdult
                        && (
                            _settingsService.ShowNonJapaneseAnime || x.Media.CountryOfOrigin == "JP"
                        )
                )
                .Select(x => x.Media!)
                .GroupBy(x => x.Id)
                .Select(x => x.First())
                .ToList();

            LastUpdatedAnimes.Clear();
            LastUpdatedAnimes.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadTrending()
    {
        try
        {
            var result = await _anilistClient.GetTrendingMediaAsync(
                new MediaTrendFilter() { Sort = MediaTrendSort.Popularity },
                new AniPaginationOptions()
            );

            var data = result
                .Data
                .Where(
                    x =>
                        x.Media is not null
                        && (
                            _settingsService.ShowNonJapaneseAnime || x.Media.CountryOfOrigin == "JP"
                        )
                )
                .Select(x => x.Media!)
                .ToList();

            TrendingAnimes.Clear();
            TrendingAnimes.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
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

        try
        {
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
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            CurrentSeasonAnimes.Clear();
            CurrentSeasonAnimes.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    private async void LoadPopular()
    {
        try
        {
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
                .Data
                .Where(x => _settingsService.ShowNonJapaneseAnime || x.CountryOfOrigin == "JP")
                .ToList();

            PopularAnimes.Clear();
            PopularAnimes.Push(data);
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }
}
