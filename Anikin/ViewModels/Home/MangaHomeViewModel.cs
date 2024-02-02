using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Anikin.Models.Manga;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.Manga;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Jita.AniList.Parameters;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels.Home;

public partial class MangaHomeViewModel : BaseViewModel
{
    private readonly AniClient _anilistClient;
    private readonly SettingsService _settingsService;

    public ObservableRangeCollection<Media> PopularMedias { get; set; } = [];
    public ObservableRangeCollection<Media> LastUpdatedMedias { get; set; } = [];

    public ObservableRangeCollection<MangaHomeRange> Ranges { get; set; } = [];

    [ObservableProperty]
    MangaHomeRange _selectedRange;

    public MangaHomeViewModel(AniClient anilistClient, SettingsService settingsService)
    {
        _anilistClient = anilistClient;
        _settingsService = settingsService;

        _settingsService.Load();

        //Load();

        var homeTypes = Enum.GetValues(typeof(MangaHomeTypes)).Cast<MangaHomeTypes>();
        Ranges.AddRange(homeTypes.Select(x => new MangaHomeRange(x)));
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
    async Task ItemSelected(Media item)
    {
        var navigationParameter = new Dictionary<string, object> { { "Media", item } };

        await Shell.Current.GoToAsync(nameof(MangaPage), navigationParameter);
    }

    [RelayCommand]
    async Task GoToSearch()
    {
        await Shell.Current.GoToAsync(nameof(MangaSearchView));
    }

    [RelayCommand]
    void RangeSelected(MangaHomeRange range)
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        range.IsSelected = true;

        SelectedRange = range;

        switch (range.Type)
        {
            case MangaHomeTypes.Popular:
                break;
            case MangaHomeTypes.LastUpdated:
                break;
            case MangaHomeTypes.Trending:
                LoadTrending();
                break;
            case MangaHomeTypes.NewSeason:
                LoadNewSeason();
                break;
            case MangaHomeTypes.FeminineMedia:
                LoadFeminineMedia();
                break;
            case MangaHomeTypes.MaleMedia:
                LoadMaleMedia();
                break;
            case MangaHomeTypes.TrashMedia:
                LoadTrashMedia();
                break;
        }
    }

    private async void LoadMaleMedia()
    {
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.MaleMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shounen"] = true },
                    Type = MediaType.Manga,
                    IsAdult = false,
                    Sort = MediaSort.Popularity
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseManga || x.CountryOfOrigin == "JP")
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
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.FeminineMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Tags = new Dictionary<string, bool>() { ["Shoujo"] = true },
                    Type = MediaType.Manga,
                    IsAdult = false,
                    Sort = MediaSort.Popularity
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseManga || x.CountryOfOrigin == "JP")
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
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.TrashMedia);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Manga,
                    IsAdult = false,
                    Sort = MediaSort.Favorites,
                    SortDescending = false
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseManga || x.CountryOfOrigin == "JP")
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
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.NewSeason);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter { Season = MediaSeason.Winter }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseManga || x.CountryOfOrigin == "JP")
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
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.LastUpdated);

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
                    SortDescending = true
                },
                new AniPaginationOptions(1, 50)
            );

            var data = recentlyUpdateResult
                .Data.Where(x =>
                    x.Media is not null
                    && !x.Media.IsAdult
                    && (_settingsService.ShowNonJapaneseManga || x.Media.CountryOfOrigin == "JP")
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
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.Trending);

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
                    && (_settingsService.ShowNonJapaneseManga || x.Media.CountryOfOrigin == "JP")
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

    private async void LoadPopular()
    {
        var rangeItem = Ranges.First(x => x.Type == MangaHomeTypes.Popular);

        try
        {
            rangeItem.IsLoading = true;
            rangeItem.Medias.Clear();

            var result = await _anilistClient.SearchMediaAsync(
                new SearchMediaFilter()
                {
                    Type = MediaType.Manga,
                    Sort = MediaSort.Popularity,
                    IsAdult = false,
                }
            );

            var data = result
                .Data.Where(x => _settingsService.ShowNonJapaneseManga || x.CountryOfOrigin == "JP")
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
