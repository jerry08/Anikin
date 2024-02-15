using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Services;
using Anikin.Utils;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Framework;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Httpz;
using Jita.AniList;
using Jita.AniList.Models;
using Juro.Core.Models.Manga;
using Juro.Core.Providers;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Storage;
using TaskExecutor;

namespace Anikin.ViewModels.Manga;

public partial class MangaReaderViewModel
    : CollectionViewModel<IMangaChapterPage>,
        IQueryAttributable
{
    private readonly AniClient _anilistClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly SettingsService _settingsService = new();

    private readonly Downloader _downloader = new();

    private readonly IMangaProvider? _provider = ProviderResolver.GetMangaProvider();

    public static List<IMangaChapter> Chapters { get; private set; } = [];

    [ObservableProperty]
    private Media? _media;

    [ObservableProperty]
    private string? _providerName;

    //private IMangaInfo Manga { get; set; } = default!;

    [ObservableProperty]
    IMangaChapter _mangaChapter = default!;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    public MangaReaderViewModel(AniClient aniClient)
    {
        _anilistClient = aniClient;

        _playerSettings.Load();
        _settingsService.Load();

        Shell.Current.Navigating += Current_Navigating;
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        Media = (Media)query["Media"];
        //Manga = (IMangaInfo)query["MangaInfo"];
        MangaChapter = (IMangaChapter)query["MangaChapter"];

        Media.Description = Html.ConvertToPlainText(Media.Description);

        Title = $"Chapter {MangaChapter.Number}";
        ProviderName = _provider?.Name;

        OnPropertyChanged(nameof(Media));
    }

    private void Current_Navigating(object? sender, ShellNavigatingEventArgs e)
    {
        Shell.Current.Navigating -= Current_Navigating;

        if (e.Source is ShellNavigationSource.PopToRoot or ShellNavigationSource.Pop)
        {
            Cancel();

            foreach (var page in Entities)
            {
                try
                {
                    if (File.Exists(page.Image))
                        File.Delete(page.Image);
                }
                catch { }
            }

#if ANDROID
            Platform.CurrentActivity.ShowSystemBars();
#endif
        }
    }

    protected override async Task LoadCore()
    {
        if (_provider is null)
        {
            IsBusy = false;
            IsRefreshing = false;
            await Toast.Make("No providers installed").Show();
            return;
        }

#if ANDROID
        Platform.CurrentActivity.HideSystemBars();
#endif

        IsBusy = true;
        IsRefreshing = true;

        try
        {
            var pages = await _provider.GetChapterPagesAsync(MangaChapter.Id, CancellationToken);
            if (pages.Count == 0)
            {
                await Toast.Make("Nothing found").Show();
                return;
            }

            await DownloadPagesAsync(pages);

            Entities.Push(pages);
            OnPropertyChanged(nameof(Entities));
        }
        catch (Exception ex)
        {
            if (App.IsInDeveloperMode)
            {
                await App.AlertService.ShowAlertAsync("Error", $"{ex}");
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
        }
    }

    private async Task DownloadPagesAsync(List<IMangaChapterPage> pages)
    {
        Exception? exception = null;

        var functions = pages.Select(page =>
            (Func<Task>)(
                async () =>
                {
                    try
                    {
                        var path = Path.Combine(
                            FileSystem.AppDataDirectory,
                            $"img-{Guid.NewGuid()}.png"
                        );
                        if (File.Exists(path))
                            File.Delete(path);

                        await _downloader.DownloadAsync(
                            page.Image,
                            path,
                            page.Headers,
                            cancellationToken: CancellationToken
                        );

                        page.Image = path;
                    }
                    catch (Exception ex)
                    {
                        exception = ex;
                    }
                }
            )
        );

        await TaskEx.Run(functions, 15);

        if (App.IsInDeveloperMode && exception is not null)
        {
            await App.AlertService.ShowAlertAsync("Error", $"{exception}");
        }
    }

    public override void OnAppearing()
    {
        base.OnAppearing();

        Shell.Current.Navigating -= Current_Navigating;
        Shell.Current.Navigating += Current_Navigating;
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

    public void Cancel() => _cancellationTokenSource.Cancel();
}
