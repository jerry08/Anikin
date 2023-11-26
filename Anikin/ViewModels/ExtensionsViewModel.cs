using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Services;
using Anikin.Utils.Extensions;
using Anikin.ViewModels.Framework;
using Anikin.ViewModels.Popups;
using Anikin.Views.Popups;
using Berry.Maui.Controls;
using CommunityToolkit.Maui.Views;
using CommunityToolkit.Mvvm.Input;
using Juro;
using Juro.Clients;
using Juro.Core.Models.Anime;
using Microsoft.Maui.Controls;

namespace Anikin.ViewModels;

public partial class ExtensionsViewModel : CollectionViewModel<ModuleListGroup<ModuleItem>>
{
    private readonly ProviderService _providerService;

    //private readonly List<IAnimeProvider> _providers;
    private readonly BottomSheet? _bottomSheet;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private bool IsLoaded { get; set; }

    public ExtensionsViewModel(ProviderService providerService)
    {
        _providerService = providerService;
        //_providers = ProviderResolver.GetAnimeProviders();

        Load();
    }

    protected override async Task LoadCore()
    {
        if (!IsRefreshing)
            IsBusy = true;

        try
        {
            if (IsLoaded)
                return;

            //var result = _providers
            //    .Where(
            //        x =>
            //            string.IsNullOrWhiteSpace(Query)
            //            || x.GetLanguageDisplayName()
            //                .Contains(Query, StringComparison.OrdinalIgnoreCase)
            //    )
            //    .ToList();

            var modules = Locator.Instance.GetModules();
            foreach (var module in modules)
            {
                var list = new AnimeClient()
                    .GetProviders(module.FilePath)
                    .Select(
                        x =>
                            new ModuleItem()
                            {
                                Name = x.Name,
                                Language = x.Language,
                                LanguageDisplayName = x.GetLanguageDisplayName(),
                                Module = module
                            }
                    )
                    .ToList();

                Push(new List<ModuleListGroup<ModuleItem>>() { new(module, list) });
            }

            //Push(result);
        }
        catch (Exception ex)
        {
            if (!CancellationToken.IsCancellationRequested)
            {
                await App.AlertService.ShowAlertAsync("Error", ex.ToString());
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
            IsLoaded = true;
        }
    }

    [RelayCommand]
    async Task ItemSelected(IAnimeInfo item)
    {
        //await _bottomSheet.DismissAsync();
        //await _episodeViewModel.LoadEpisodes(item);
    }

    [RelayCommand]
    async Task AddExtension()
    {
        if (Application.Current?.MainPage is null)
            return;

        var viewModel = new ExtensionsPopupViewModel();
        var popup = new ExtensionsPopup(viewModel);
        var result = await Application.Current.MainPage.ShowPopupAsync(popup);

        if (result is bool boolResult)
        {
            if (boolResult)
            {
                if (string.IsNullOrWhiteSpace(viewModel.RepoUrl))
                {
                    await App.AlertService.ShowAlertAsync("", "Invalid url");
                    return;
                }

                await DownloadExtensionAsync(viewModel.RepoUrl);
            }
        }
    }

    async Task DownloadExtensionAsync(string repoUrl)
    {
        await _providerService.DownloadAsync(repoUrl);
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
