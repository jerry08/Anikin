using System;
using System.Linq;
using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Anikin.ViewModels;

public partial class AppUpdateViewModel : CollectionViewModel<PluginListGroup<PluginItem>>
{
    private readonly UpdateService _updateService;

    [ObservableProperty]
    string? _htmlContent;

    public AppUpdateViewModel(UpdateService updateService)
    {
        _updateService = updateService;

        HtmlContent = _updateService.RenderedMarkdown;
    }

    [RelayCommand]
    async Task Download()
    {
        if (_updateService.Release is null)
        {
            return;
        }

        var asset = _updateService.Release.Assets[0];

        if (OperatingSystem.IsWindows())
        {
            asset = _updateService.Release.Assets.FirstOrDefault(x =>
                x.Name.Contains("windows", StringComparison.OrdinalIgnoreCase)
            );
        }

        if (asset is null)
            return;

        await DownloadCenter.Current.EnqueueAsync(asset.Name, asset.BrowserDownloadUrl);
    }
}
