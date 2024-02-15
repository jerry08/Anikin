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
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Jita.AniList;
using Jita.AniList.Models;
using Juro.Core.Models.Manga;
using Juro.Core.Providers;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels.Manga;

public partial class MangaItemViewModel : CollectionViewModel<IMangaChapter>, IQueryAttributable
{
    private readonly AniClient _anilistClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly SettingsService _settingsService = new();

    private IMangaProvider? _provider = ProviderResolver.GetMangaProvider();
    private readonly List<IMangaProvider> _providers = ProviderResolver.GetMangaProviders();

    public static List<IMangaChapter> Chapters { get; private set; } = [];

    public ObservableRangeCollection<string> ProviderNames { get; set; } = [];

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
    private bool _isDubSelected;

    private bool IsSavingFavorite { get; set; }

    private bool IsProviderSearchSheetShowing { get; set; }

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private ChangeMangaSourceSheet? ChangeSourceSheet { get; set; }

    public MangaItemViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        SelectedViewModelIndex = 1;

        ProviderNames.AddRange(_providers.ConvertAll(x => x.Name));

        var providers = _providers.Select(x => new ProviderModel()
        {
            Key = x.Key,
            Language = x.Language,
            Name = x.Name,
            LanguageDisplayName = x.GetLanguageDisplayName()
        });

        var selectedProvider = _providers.Find(x => x.Key == _provider?.Key);

        var groups = providers.GroupBy(x => x.LanguageDisplayName);
        foreach (var group in groups)
        {
            ProviderGroups.Add(new(group.Key, group.ToList()));
        }

        var list = ProviderGroups.SelectMany(x => x).ToList();
        list.ForEach(x => x.IsSelected = false);

        var defaultProvider = list.Find(x => x.Key == selectedProvider?.Key);
        if (defaultProvider is not null)
        {
            defaultProvider.IsSelected = true;
        }

        //Load();

        _playerSettings.Load();
        _settingsService.Load();

        GridLayoutMode = _settingsService.MangaItemsGridLayoutMode;

        Shell.Current.Navigating += Current_Navigating;
    }

    private void Current_Navigating(object? sender, ShellNavigatingEventArgs e)
    {
        Shell.Current.Navigating -= Current_Navigating;

        if (e.Source is ShellNavigationSource.PopToRoot or ShellNavigationSource.Pop)
            Cancel();
    }

    [RelayCommand]
    private async Task ShowProviderSourcesSheet()
    {
        ChangeSourceSheet = new() { BindingContext = this };
        await ChangeSourceSheet.ShowAsync();
    }

    [RelayCommand]
    private async Task SelectedProviderKeyChanged(string? key)
    {
        if (string.IsNullOrWhiteSpace(key) || _provider?.Key == key)
            return;

        if (ChangeSourceSheet is not null)
        {
            await ChangeSourceSheet.DismissAsync();
            ChangeSourceSheet = null;
        }

        var provider = _providers.Find(x => x.Key == key);
        if (provider is null)
            return;

        var list = ProviderGroups.SelectMany(x => x).ToList();
        list.ForEach(x => x.IsSelected = false);

        var defaultProvider = list.Find(x => x.Key == provider.Key);
        if (defaultProvider is not null)
        {
            defaultProvider.IsSelected = true;
        }

        await Snackbar.Make($"Source provider changed to {provider.Name}").Show();

        _settingsService.LastProviderKey = provider.Key;
        _settingsService.Save();

        Entities.Clear();

        _provider = provider;

        await LoadCore();
    }

    protected override async Task LoadCore()
    {
        if (Media is null)
        {
            IsBusy = false;
            IsRefreshing = false;
            return;
        }

        if (_provider is null)
        {
            IsBusy = false;
            IsRefreshing = false;
            await Toast.Make("No providers installed").Show();
            return;
        }

        IsBusy = true;
        IsRefreshing = true;

        try
        {
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

        if (_provider is null)
        {
            await Toast.Make("No providers installed").Show();
            return;
        }

        try
        {
            var result = await _provider.GetMangaInfoAsync(manga.Id, CancellationToken);
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
        if (_provider is null)
            return null;

        try
        {
            var dubText = IsDubSelected ? " (dub)" : "";

            SearchingText = $"Searching : {Media.Title?.PreferredTitle}" + dubText;

            var result = await _provider.SearchAsync(
                Media.Title.RomajiTitle + dubText,
                CancellationToken
            );

            if (result.Count == 0)
            {
                result = await _provider.SearchAsync(
                    Media.Title.NativeTitle + dubText,
                    CancellationToken
                );
            }

            if (result.Count == 0)
            {
                result = await _provider.SearchAsync(
                    Media.Title.EnglishTitle + dubText,
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
            ["MangaChapter"] = chapter
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
                Title = "Share Anilist Link"
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
