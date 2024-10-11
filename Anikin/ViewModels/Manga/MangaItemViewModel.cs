using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Models.Manga;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Components;
using Anikin.ViewModels.Framework;
using Anikin.Views.BottomSheets;
using Anikin.Views.Manga;
using Berry.Maui.Extensions;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Juro.Clients;
using Juro.Core.Models;
using Juro.Core.Models.Manga;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels.Manga;

public partial class MangaItemViewModel : CollectionViewModel<IMangaChapter>, IQueryAttributable
{
    private readonly MangaApiClient _apiClient = new(Constants.ApiEndpoint);
    private readonly AniClient _anilistClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly SettingsService _settingsService = new();

    private List<Provider> Providers { get; set; } = [];

    public static List<IMangaChapter> Chapters { get; private set; } = [];

    public ObservableRangeCollection<string> ProviderNames { get; set; } = [];

    private string? SelectedProviderName { get; set; }

    public ObservableRangeCollection<ListGroup<ProviderModel>> ProviderGroups { get; set; } = [];

    [ObservableProperty]
    private Media? _media;

    private IMangaResult? Manga { get; set; }

    public ObservableRangeCollection<MangaChapterRange> Ranges { get; set; } = [];

    public List<IMangaChapter[]> MangaChapterChunks { get; set; } = [];

    [ObservableProperty]
    private string? _searchingText;

    [ObservableProperty]
    private int _selectedViewModelIndex;

    [ObservableProperty]
    private bool _isFavorite;

    [ObservableProperty]
    private GridLayoutMode _gridLayoutMode;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(ShowProviderSourcesSheetCommand))]
    private bool _isLoadingProviders;

    private bool IsSavingFavorite { get; set; }

    private bool IsProviderSearchSheetShowing { get; set; }

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private ChangeMangaSourceSheet? ChangeSourceSheet { get; set; }

    public MangaItemViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        SelectedViewModelIndex = 1;

        //Load();

        _playerSettings.Load();
        _settingsService.Load();

        _apiClient.ProviderKey = _settingsService.LastMangaProviderKey!;

        GridLayoutMode = _settingsService.MangaItemsGridLayoutMode;

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
            $"Select Provider ({_settingsService.LastMangaProviderKey ?? "??"})",
            "Cancel",
            "Ok",
            providersName.ToArray()
        );
        if (string.IsNullOrWhiteSpace(result))
            return;

        var index = providersName.IndexOf(result);
        if (index <= 0)
            return;

        await SelectedProviderKeyChanged(providers[index].Key);
#endif
    }

    [RelayCommand]
    private async Task SelectedProviderKeyChanged(string? key)
    {
        if (string.IsNullOrWhiteSpace(key) || _settingsService.LastMangaProviderKey == key)
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

        _settingsService.LastMangaProviderKey = provider.Key;
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

        var defaultProvider = list.Find(x => x.Key == _settingsService.LastMangaProviderKey);
        if (defaultProvider is not null)
        {
            defaultProvider.IsSelected = true;
        }

        _apiClient.ProviderKey = _settingsService.LastMangaProviderKey!;
    }

    protected override async Task LoadCore()
    {
        if (Media is null)
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
            Manga = await TryFindBestManga();

            if (CancellationToken.IsCancellationRequested)
                return;

            if (Manga is null)
            {
                await Toast.Make("Nothing found").Show();
                await ShowProviderSearch();
                return;
            }

            await LoadChapters(Manga);
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

    public async Task LoadChapters(IMangaResult manga)
    {
        Manga = manga;

        SearchingText = $"Found : {manga.Title}";

        IsBusy = true;
        IsRefreshing = true;

        Ranges.Clear();
        Entities.Clear();

        try
        {
            var result = await _apiClient.GetAsync(manga.Id, CancellationToken);
            if (result is null || result.Chapters.Count == 0)
                return;

            //result = result.OrderBy(x => x.Number).ToList();

            Chapters.Clear();
            Chapters.AddRange(result.Chapters);

            MangaChapterChunks = result.Chapters.Chunk(50).ToList();

            var ranges = new List<MangaChapterRange>();

            if (MangaChapterChunks.Count > 1)
            {
                var startIndex = 1;
                var endIndex = 0;

                for (var i = 0; i < MangaChapterChunks.Count; i++)
                {
                    if (_settingsService.MangaChaptersDescending)
                    {
                        MangaChapterChunks[i] = MangaChapterChunks[i].Reverse().ToArray();
                    }

                    endIndex = startIndex + MangaChapterChunks[i].Length - 1;
                    ranges.Add(new(MangaChapterChunks[i], startIndex, endIndex));
                    startIndex += MangaChapterChunks[i].Length;
                }

                ranges[0].IsSelected = true;
            }
            else
            {
                if (_settingsService.MangaChaptersDescending)
                {
                    MangaChapterChunks[0] = MangaChapterChunks[0].Reverse().ToArray();
                }
            }

            RefreshProgress();

#if WINDOWS
            // MAUI issue on Windows where list is reversed in view although it's the
            // correct order here in the ViewModel, so reverse the list to display correct order.
            ranges.Reverse();
#endif

            Ranges.Push(ranges);
            OnPropertyChanged(nameof(Ranges));

            Entities.Push(MangaChapterChunks[0]);
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
    private void RangeSelected(MangaChapterRange range)
    {
        for (var i = 0; i < Ranges.Count; i++)
        {
            Ranges[i].IsSelected = false;
        }

        range.IsSelected = true;

        Entities.ReplaceRange(range.Chapters);
    }

    private void RefreshProgress()
    {
        if (MangaChapterChunks.Count == 0)
            return;

        _playerSettings.Load();

        //foreach (var list in MangaChapterChunks)
        //{
        //    foreach (var chapter in list)
        //    {
        //        var episodeKey = $"{Media.Id}-{chapter.Page}";
        //        _playerSettings.WatchedEpisodes.TryGetValue(episodeKey, out var watchedEpisode);
        //        if (watchedEpisode is not null)
        //        {
        //            chapter.Progress = watchedEpisode.WatchedPercentage;
        //        }
        //    }
        //}

        Entities.Clear();
        Entities.Push(MangaChapterChunks[0]);
    }

    private async Task<IMangaResult?> TryFindBestManga()
    {
        try
        {
            SearchingText = $"Searching : {Media.Title?.PreferredTitle}";

            var result = await _apiClient.SearchAsync(Media.Title.RomajiTitle, CancellationToken);
            if (result.Count == 0)
            {
                result = await _apiClient.SearchAsync(Media.Title.NativeTitle, CancellationToken);
            }

            if (result.Count == 0)
            {
                result = await _apiClient.SearchAsync(Media.Title.EnglishTitle, CancellationToken);
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

        RefreshProgress();
    }

    [RelayCommand]
    private async Task ItemClick(IMangaChapter chapter)
    {
        if (Media is null)
            return;

        var navigationParameter = new Dictionary<string, object>()
        {
            ["Media"] = Media,
            ["MangaChapter"] = chapter,
        };

        await Shell.Current.GoToAsync(nameof(MangaReaderPage), navigationParameter);
    }

    [RelayCommand]
    private async Task ShowCoverImage()
    {
        var sheet = new MangaCoverImageSheet() { BindingContext = this };

        await sheet.ShowAsync();
    }

    [RelayCommand]
    private async Task CopyTitle()
    {
        if (!string.IsNullOrWhiteSpace(Media?.Title?.PreferredTitle))
        {
            await Clipboard.Default.SetTextAsync(Media.Title.PreferredTitle);

            await Toast
                .Make(
                    $"Copied to clipboard:{Environment.NewLine}{Media.Title.PreferredTitle}",
                    ToastDuration.Short,
                    18
                )
                .Show();
        }
    }

    [RelayCommand]
    async Task ShowSheet(IMangaChapter chapter)
    {
        //if (Manga is null)
        //    return;
        //
        //var sheet = new VideoSourceSheet();
        //sheet.BindingContext = new VideoSourceViewModel(sheet, Manga, chapter, Media);
        //
        //await sheet.ShowAsync();
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
                Media.Id,
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
            var media = await _anilistClient.GetMediaAsync(Media.Id);
            Media.IsFavorite = media.IsFavorite;
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
        if (Media?.Url is null)
            return;

        await Share.Default.RequestAsync(
            new ShareTextRequest
            {
                //Uri = $"https://anilist.cs/manga/{Media.Id}",
                Uri = Media.Url.OriginalString,
                Title = "Share Anilist Link",
            }
        );
    }

    [RelayCommand]
    private void ChangeGridMode(GridLayoutMode gridLayoutMode)
    {
        GridLayoutMode = gridLayoutMode;
        _settingsService.MangaItemsGridLayoutMode = gridLayoutMode;
        _settingsService.Save();
    }

    [RelayCommand]
    private async Task ShowProviderSearch()
    {
        if (IsProviderSearchSheetShowing)
            return;

        IsProviderSearchSheetShowing = true;

        var sheet = new MangaProviderSearchSheet();
        sheet.BindingContext = new MangaProviderSearchViewModel(
            this,
            sheet,
            Media.Title.PreferredTitle
        );

        sheet.Dismissed += (_, _) => IsProviderSearchSheetShowing = false;

        await sheet.ShowAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        Media = (Media)query["Media"];
        Media.Description = Html.ConvertToPlainText(Media.Description);
        IsFavorite = Media.IsFavorite;

        OnPropertyChanged(nameof(Media));

        RefreshIsFavorite();
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
