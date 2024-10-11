using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Components;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.BottomSheets;
using Berry.Maui.Extensions;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Juro.Clients;
using Juro.Core.Models;
using Juro.Core.Models.Anime;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;
using EpisodeRange = Anikin.Models.EpisodeRange;

namespace Anikin.ViewModels;

public partial class EpisodeViewModel : CollectionViewModel<Episode>, IQueryAttributable
{
    private readonly AnimeApiClient _apiClient = new(Constants.ApiEndpoint);
    private readonly AniClient _anilistClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly SettingsService _settingsService = new();

    private List<Provider> Providers { get; set; } = [];

    public ObservableRangeCollection<ListGroup<ProviderModel>> ProviderGroups { get; set; } = [];

    public static List<Episode> Episodes { get; private set; } = [];

    public ObservableRangeCollection<string> ProviderNames { get; set; } = [];

    [ObservableProperty]
    private Media _entity = default!;

    private IAnimeInfo? Anime { get; set; }

    public ObservableRangeCollection<EpisodeRange> Ranges { get; set; } = [];

    private List<Episode[]> EpisodeChunks { get; set; } = [];

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
    [NotifyCanExecuteChangedFor(nameof(ShowProviderSourcesSheetCommand))]
    private bool _isLoadingProviders;

    private bool IsSavingFavorite { get; set; }

    private bool IsProviderSearchSheetShowing { get; set; }

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private ChangeSourceSheet? ChangeSourceSheet { get; set; }

    public EpisodeViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        SelectedViewModelIndex = 1;

        //Load();

        _playerSettings.Load();
        _settingsService.Load();

        GridLayoutMode = _settingsService.EpisodesGridLayoutMode;

        Shell.Current.Navigating += Current_Navigating;

        IsLoadingProviders = true;
        LoadProviderSources().FireAndForget();
    }

    private void Current_Navigating(object? sender, ShellNavigatingEventArgs e)
    {
        Shell.Current.Navigating -= Current_Navigating;

        if (e.Source is ShellNavigationSource.PopToRoot or ShellNavigationSource.Pop)
            Cancel();
    }

    async partial void OnIsDubSelectedChanged(bool value)
    {
        Entities.Clear();

        await LoadCore();
    }

    private async Task LoadProviderSources()
    {
        if (Providers.Count > 0)
            return;

        try
        {
            Providers = await _apiClient.GetProvidersAsync();
        }
        catch
        {
            await Toast.Make("Failed to load providers").Show();
        }

        if (string.IsNullOrEmpty(_settingsService.LastAnimeProviderName))
        {
            _settingsService.LastAnimeProviderName = Providers.FirstOrDefault()?.Key;
            _settingsService.Save();
        }

        IsLoadingProviders = false;

        ProviderNames.Clear();
        ProviderNames.AddRange(Providers.ConvertAll(x => x.Name));
    }

    [RelayCommand]
    private async Task ShowProviderSourcesSheet()
    {
#if ANDROID || IOS
        ChangeSourceSheet = new() { BindingContext = this };
        await ChangeSourceSheet.ShowAsync();
#else
        var providers = ProviderGroups.SelectMany(x => x).ToList();
        var providersName = providers.Select(x => x.Name).ToList();

        var result = await Shell.Current.DisplayActionSheet(
            $"Select Provider ({_settingsService.LastAnimeProviderKey ?? "??"})",
            "Cancel",
            "Ok",
            providersName.ToArray()
        );
        if (string.IsNullOrWhiteSpace(result))
            return;

        var index = providersName.IndexOf(result);
        if (index < 0)
            return;

        await SelectedProviderKeyChanged(providers[index].Key);
#endif
    }

    [RelayCommand]
    private async Task SelectedProviderKeyChanged(string? key)
    {
        if (string.IsNullOrWhiteSpace(key) || _settingsService.LastAnimeProviderKey == key)
            return;

        if (ChangeSourceSheet is not null)
        {
            await ChangeSourceSheet.DismissAsync();
            ChangeSourceSheet = null;
        }

        var provider = Providers.Find(x => x.Key == key);
        if (provider is null)
            return;

        await Snackbar.Make($"Source provider changed to {provider.Name}").Show();

        _settingsService.LastAnimeProviderKey = provider.Key;
        _settingsService.LastAnimeProviderName = provider.Name;
        _settingsService.Save();

        SelectDefaultProvider();

        Entities.Clear();

        await LoadCore();
    }

    private void SelectDefaultProvider()
    {
        var providerModels = Providers.Select(x => new ProviderModel()
        {
            Key = x.Key,
            //Language = x.Language,
            Language = "en",
            Name = x.Name,
            //LanguageDisplayName = x.GetLanguageDisplayName(),
        });

        ProviderGroups.Clear();

        var groups = providerModels.GroupBy(x => x.LanguageDisplayName);
        foreach (var group in groups)
        {
            ProviderGroups.Add(new(group.Key, group.ToList()));
        }

        var list = ProviderGroups.SelectMany(x => x).ToList();
        list.ForEach(x => x.IsSelected = false);

        var defaultProvider = list.Find(x => x.Key == _settingsService.LastAnimeProviderKey);
        if (defaultProvider is not null)
        {
            defaultProvider.IsSelected = true;
        }

        _apiClient.ProviderKey = _settingsService.LastAnimeProviderKey!;
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
            while (IsLoadingProviders)
            {
                // Delay is necessary in windows release mode (while not debugging).
                // Otherwise the app will freeze.
                await Task.Delay(500);
            }

            if (Providers.Count == 0)
                return;

            SelectDefaultProvider();

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
            var result = await _apiClient.GetEpisodesAsync(anime.Id, CancellationToken);
            if (result.Count == 0)
                return;

            result = result.OrderBy(x => x.Number).ToList();

            Episodes.Clear();
            Episodes.AddRange(result);

            EpisodeChunks = result.Chunk(50).ToList();

            var ranges = new List<EpisodeRange>();

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
                    ranges.Add(new(EpisodeChunks[i], startIndex, endIndex));
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
        catch (Exception ex)
        {
            if (App.IsInDeveloperMode)
            {
                await App.AlertService.ShowAlertAsync("Error", $"{ex}");
            }

            SearchingText = "Nothing Found";
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
    }

    [RelayCommand]
    private void RangeSelected(EpisodeRange range)
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        range.IsSelected = true;

        Entities.ReplaceRange(range.Episodes);
    }

    [RelayCommand]
    private void Sort()
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        //range.IsSelected = true;
        //
        //Entities.ReplaceRange(range.Episodes);
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

            var result = await _apiClient.SearchAsync(
                Entity.Title.RomajiTitle + dubText,
                CancellationToken
            );

            if (result.Count == 0)
            {
                result = await _apiClient.SearchAsync(
                    Entity.Title.NativeTitle + dubText,
                    CancellationToken
                );
            }

            if (result.Count == 0)
            {
                result = await _apiClient.SearchAsync(
                    Entity.Title.EnglishTitle + dubText,
                    CancellationToken
                );
            }

            return result.FirstOrDefault();
        }
        catch (Exception ex)
        {
            if (App.IsInDeveloperMode)
            {
                await App.AlertService.ShowAlertAsync("Error", $"{ex}");
            }

            SearchingText = "Nothing found";

            return null;
        }
    }

    public override void OnAppearing()
    {
        base.OnAppearing();

        Shell.Current.Navigating -= Current_Navigating;
        Shell.Current.Navigating += Current_Navigating;

        RefreshEpisodesProgress();
    }

    [RelayCommand]
    private async Task ItemClick(Episode episode)
    {
        if (Anime is null)
            return;

        var page = new VideoPlayerView
        {
            BindingContext = new VideoPlayerViewModel(Anime, episode, Entity),
        };

        await Shell.Current.Navigation.PushAsync(page);
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
            await Toast.Make(ex.ToString(), ToastDuration.Long).Show();
        }
        finally
        {
            IsSavingFavorite = false;
        }

        await RefreshIsFavorite();
    }

    private async Task RefreshIsFavorite()
    {
        if (string.IsNullOrWhiteSpace(_settingsService.AnilistAccessToken))
        {
            return;
        }

        try
        {
            var media = await _anilistClient.GetMediaAsync(Entity.Id);
            Entity.IsFavorite = media.IsFavorite;
            //IsFavorite = media.IsFavorite;
        }
        catch (Exception ex)
        {
            await Toast.Make(ex.ToString(), ToastDuration.Long).Show();
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
                Title = "Share Anilist Link",
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
