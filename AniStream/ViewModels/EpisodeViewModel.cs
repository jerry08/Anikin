﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
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

    private IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();
    private readonly List<IAnimeProvider> _providers = ProviderResolver.GetAnimeProviders();

    public static List<Episode> Episodes { get; private set; } = new();

    public ObservableRangeCollection<string> ProviderNames { get; set; } = new();

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

    [ObservableProperty]
    private bool _isDubSelected;

    [ObservableProperty]
    private int _providerIndex;

    private bool IsSavingFavorite { get; set; }

    private bool IsProviderSearchSheetShowing { get; set; }

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    public EpisodeViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        SelectedViewModelIndex = 1;

        ProviderNames.AddRange(_providers.ConvertAll(x => x.Name));

        var providerIndex = _providers.FindIndex(x => x.Key == _provider.Key);
        if (providerIndex < 0)
            providerIndex = 0;

        ProviderIndex = providerIndex;

        //Load();

        _playerSettings.Load();
        _settingsService.Load();

        GridLayoutMode = _settingsService.EpisodesGridLayoutMode;

        PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(IsDubSelected))
                IsDubSelectedChanged();
        };

        Shell.Current.Navigating += Current_Navigating;
    }

    private void Current_Navigating(object? sender, ShellNavigatingEventArgs e)
    {
        Shell.Current.Navigating -= Current_Navigating;
        _cancellationTokenSource.Cancel();
    }

    private async void IsDubSelectedChanged()
    {
        Entities.Clear();
        await LoadCore();
    }

    [RelayCommand]
    private async Task ProviderChanged(int index)
    {
        Entities.Clear();

        var provider = _providers[index];

        _settingsService.LastProviderKey = provider.Key;
        _settingsService.Save();

        _provider = provider;

        await LoadCore();
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

            if (CancellationToken.IsCancellationRequested)
                return;

            if (Anime is null)
            {
                await Toast.Make("Nothing found").Show();
                await ShowProviderSearch();
                return;
            }

            await LoadEpisodes(Anime);
        }
        catch
        {
            if (!CancellationToken.IsCancellationRequested)
            {
                SearchingText = "Nothing Found";
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
    }

    public async Task LoadEpisodes(IAnimeInfo anime)
    {
        Anime = anime;

        SearchingText = $"Found : {anime.Title}";

        //var animeInfo = await _provider.GetAnimeInfoAsync(anime.Id);
        //Entity = animeInfo;
        //OnPropertyChanged(nameof(Entity));

        IsBusy = true;
        IsRefreshing = true;

        Ranges.Clear();
        Entities.Clear();

        try
        {
            var result = await _provider.GetEpisodesAsync(anime.Id, CancellationToken);
            if (result.Count == 0)
                return;

            result = result.OrderBy(x => x.Number).ToList();

            Episodes.Clear();
            Episodes.AddRange(result);

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

            Ranges.Push(ranges);
            OnPropertyChanged(nameof(Ranges));

            Entities.Push(EpisodeChunks[0]);
            OnPropertyChanged(nameof(Entities));
        }
        catch
        {
            SearchingText = "Nothing Found";
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
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
            var dubText = IsDubSelected ? " (dub)" : "";

            SearchingText = $"Searching : {Entity.Title?.PreferredTitle}" + dubText;

            var result = await _provider.SearchAsync(
                Entity.Title.RomajiTitle + dubText,
                CancellationToken
            );

            if (result.Count == 0)
            {
                result = await _provider.SearchAsync(
                    Entity.Title.NativeTitle + dubText,
                    CancellationToken
                );
            }

            if (result.Count == 0)
            {
                result = await _provider.SearchAsync(
                    Entity.Title.EnglishTitle + dubText,
                    CancellationToken
                );
            }

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

        var sheet = new VideoSourceSheet();
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
            //IsFavorite = media.IsFavorite;
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

        await Share
            .Default
            .RequestAsync(
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
        if (IsProviderSearchSheetShowing)
            return;

        IsProviderSearchSheetShowing = true;

        var sheet = new ProviderSearchSheet();
        sheet.BindingContext = new ProviderSearchViewModel(
            this,
            sheet,
            Entity.Title.PreferredTitle
        );

        sheet.Dismissed += (_, _) => IsProviderSearchSheetShowing = false;

        await sheet.ShowAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        Entity = (Media)query["SourceItem"];
        Entity.Description = Html.ConvertToPlainText(Entity.Description);
        IsFavorite = Entity.IsFavorite;

        OnPropertyChanged(nameof(Entity));

        RefreshIsFavorite();
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
