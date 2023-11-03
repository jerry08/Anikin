using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AniStream.Services;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using AniStream.ViewModels.Components;
using AniStream.ViewModels.Framework;
using AniStream.Views;
using AniStream.Views.BottomSheets;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Juro.Core.Models.Anime;
using Juro.Core.Providers;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;
using Range = AniStream.Models.Range;

namespace AniStream.ViewModels;

public partial class EpisodeViewModel : CollectionViewModel<Episode>, IQueryAttributable
{
    private readonly AniClient _anilistClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly SettingsService _settingsService = new();

    private readonly IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();

    [ObservableProperty]
    private Media? _entity;

    private IAnimeInfo? Anime { get; set; }

    public ObservableRangeCollection<Range> Ranges { get; set; } = new();

    public List<Episode[]> EpisodeChunks { get; set; } = new();

    [ObservableProperty]
    private string? _searchingText;

    [ObservableProperty]
    private int _selectedViewModelIndex;

    [ObservableProperty]
    private bool _isFavorite;

    [ObservableProperty]
    private GridLayoutMode _gridLayoutMode;

    private bool IsSavingFavorite { get; set; }

    public EpisodeViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        SelectedViewModelIndex = 1;

        //Load();

        _playerSettings.Load();
        _settingsService.Load();

        GridLayoutMode = _settingsService.EpisodesGridLayoutMode;
    }

    protected override async Task LoadCore()
    {
        if (Entity is null)
        {
            IsBusy = false;
            IsRefreshing = false;
            return;
        }

        IsBusy = true;
        IsRefreshing = true;

        try
        {
            // Find best match
            Anime = await TryFindBestAnime();
            if (Anime is null)
            {
                await ShowProviderSearch();
                return;
            }

            await LoadEpisodes(Anime);
        }
        catch (Exception e)
        {
            SearchingText = "Nothing Found";
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
    }

    public async Task LoadEpisodes(IAnimeInfo anime)
    {
        SearchingText = $"Found : {anime.Title}";

        //var animeInfo = await _provider.GetAnimeInfoAsync(anime.Id);
        //Entity = animeInfo;
        //OnPropertyChanged(nameof(Entity));

        var result = await _provider.GetEpisodesAsync(anime.Id);
        if (result.Count == 0)
            return;

        result = result.OrderBy(x => x.Number).ToList();

        EpisodeChunks = result.Chunk(50).ToList();

        var ranges = new List<Range>();

        if (EpisodeChunks.Count > 1)
        {
            var startIndex = 1;
            var endIndex = 0;

            for (var i = 0; i < EpisodeChunks.Count; i++)
            {
                if (_settingsService.EpisodesDescending)
                {
                    EpisodeChunks[i] = EpisodeChunks[i].Reverse().ToArray();
                }

                endIndex = startIndex + EpisodeChunks[i].Length - 1;
                ranges.Add(new Range(EpisodeChunks[i], startIndex, endIndex));
                startIndex += EpisodeChunks[i].Length;
            }

            ranges[0].IsSelected = true;
        }
        else
        {
            if (_settingsService.EpisodesDescending)
            {
                EpisodeChunks[0] = EpisodeChunks[0].Reverse().ToArray();
            }
        }

        result.ForEach(ep => ep.Image = anime.Image);

        RefreshEpisodesProgress();

        Entities.Push(EpisodeChunks[0]);
        Ranges.Push(ranges);
        OnPropertyChanged(nameof(Ranges));
    }

    [RelayCommand]
    private void RangeSelected(Range range)
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        range.IsSelected = true;

        Entities.ReplaceRange(range.Episodes);
    }

    private void RefreshEpisodesProgress()
    {
        if (EpisodeChunks.Count == 0)
            return;

        _playerSettings.Load();

        foreach (var list in EpisodeChunks)
        {
            foreach (var episode in list)
            {
                var episodeKey = $"{Entity.Id}-{episode.Number}";
                _playerSettings.WatchedEpisodes.TryGetValue(episodeKey, out var watchedEpisode);
                if (watchedEpisode is not null)
                {
                    episode.Progress = watchedEpisode.WatchedPercentage;
                }
            }
        }

        Entities.Clear();
        Entities.Push(EpisodeChunks[0]);
    }

    private async Task<IAnimeInfo?> TryFindBestAnime()
    {
        try
        {
            var result = await _provider.SearchAsync(Entity.Title.RomajiTitle);

            if (result.Count == 0)
                result = await _provider.SearchAsync(Entity.Title.NativeTitle);

            if (result.Count == 0)
                result = await _provider.SearchAsync(Entity.Title.EnglishTitle);

            return result.FirstOrDefault();
        }
        catch
        {
            return null;
        }
    }

    public override void OnAppearing()
    {
        base.OnAppearing();
        RefreshEpisodesProgress();
    }

    [RelayCommand]
    private async Task ItemClick(Episode episode)
    {
        if (Anime is null)
            return;

        var page1 = new VideoPlayerView();
        page1.BindingContext = new VideoPlayerViewModel(this.Anime, episode, Entity);

        await Shell.Current.Navigation.PushAsync(page1);
    }

    [RelayCommand]
    private async Task ShowCoverImage()
    {
        var sheet = new CoverImageSheet() { BindingContext = this };

        await sheet.ShowAsync();
    }

    [RelayCommand]
    private async Task CopyTitle()
    {
        if (!string.IsNullOrWhiteSpace(Entity?.Title?.PreferredTitle))
        {
            await Clipboard.Default.SetTextAsync(Entity.Title.PreferredTitle);

            await Toast
                .Make(
                    $"Copied to clipboard:{Environment.NewLine}{Entity.Title.PreferredTitle}",
                    ToastDuration.Short,
                    18
                )
                .Show();
        }
    }

    [RelayCommand]
    async Task ShowSheet(Episode episode)
    {
        if (Anime is null)
            return;

        //var test1 = new EpisodeSelectionSheet2();
        //Shell.Current.ShowBottomSheet(test1, false);
        //return;

        var sheet = new EpisodeSelectionSheet();
        sheet.BindingContext = new VideoSourceViewModel(sheet, Anime, episode, Entity);

        await sheet.ShowAsync();
    }

    [RelayCommand]
    private async Task FavouriteToggle()
    {
        if (string.IsNullOrWhiteSpace(_settingsService.AnilistAccessToken))
        {
            await App.AlertService.ShowAlertAsync("Notice", "Login to Anilist");
            return;
        }

        IsFavorite = !IsFavorite;

        if (IsSavingFavorite)
            return;

        IsSavingFavorite = true;

        await ToggleFavoriteAsync();
    }

    private async Task ToggleFavoriteAsync()
    {
        try
        {
            var isFavorite = await _anilistClient.ToggleMediaFavoriteAsync(
                Entity.Id,
                MediaType.Anime
            );
            if (isFavorite != IsFavorite)
            {
                await ToggleFavoriteAsync();
                return;
            }
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
        finally
        {
            IsSavingFavorite = false;
        }

        await RefreshIsFavorite();
    }

    private async Task RefreshIsFavorite()
    {
        try
        {
            var media = await _anilistClient.GetMediaAsync(Entity.Id);
            Entity.IsFavorite = media.IsFavorite;
            IsFavorite = media.IsFavorite;
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString()).Show();
        }
    }

    [RelayCommand]
    private async Task ShareUri()
    {
        if (Entity.Url is null)
            return;

        await Share.Default.RequestAsync(
            new ShareTextRequest
            {
                //Uri = $"https://anilist.cs/anime/{Entity.Id}",
                Uri = Entity.Url.OriginalString,
                Title = "Share Anilist Link"
            }
        );
    }

    [RelayCommand]
    private void ChangeGridMode(GridLayoutMode gridLayoutMode)
    {
        GridLayoutMode = gridLayoutMode;
        _settingsService.EpisodesGridLayoutMode = gridLayoutMode;
        _settingsService.Save();
    }

    [RelayCommand]
    private async Task ShowProviderSearch()
    {
        var sheet = new ProviderSearchSheet();
        sheet.BindingContext = new ProviderSearchViewModel(
            this,
            sheet,
            Entity.Title.PreferredTitle
        );
        await sheet.ShowAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        Entity = (Media)query["SourceItem"];
        Entity.Description = Html.ConvertToPlainText(Entity.Description);
        IsFavorite = Entity.IsFavorite;

        OnPropertyChanged(nameof(Entity));

        SearchingText = $"Searching : {Entity.Title?.PreferredTitle}";

        RefreshIsFavorite();
    }
}
