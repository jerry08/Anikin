using System;
using System.Linq;
using System.Threading.Tasks;
using Anikin.ViewModels;
using Anikin.Views.BottomSheets;
using Microsoft.Maui.ApplicationModel;
using Octokit;

namespace Anikin.Services;

public class UpdateService
{
    private readonly IReleasesClient _releaseClient;
    private readonly GitHubClient _github;

    private readonly string _repositoryOwner = "jerry08";
    private readonly string _repostoryName = "Anikin";

    public Release? Release { get; set; }

    public string? RenderedMarkdown { get; set; }

    public UpdateService()
    {
        _github = new GitHubClient(new ProductHeaderValue(_repostoryName + "-UpdateCheck"));
        _releaseClient = _github.Repository.Release;
    }

    public async Task<bool> CheckAsync()
    {
        try
        {
            Release = await GetReleaseAsync();
            if (Release is null)
                return false;

            var latestVersionName = new Version(Release.Name);
            var currentVersionName = AppInfo.Current.Version;

            if (currentVersionName < latestVersionName)
            {
                RenderedMarkdown = await _github.Markdown.RenderRawMarkdown(Release.Body);

                var viewModel = new AppUpdateViewModel(this);
                var sheet = new AppUpdateSheet() { BindingContext = viewModel };

                await sheet.ShowAsync();

                //var update = await App.AlertService.ShowConfirmationAsync(
                //    "Update available",
                //    "",
                //    "DOWNLOAD",
                //    "DISMISS"
                //);
                //
                //if (update)
                //{
                //    var asset = Release.Assets[0];
                //
                //    await DownloadCenter.Current.EnqueueAsync(asset.Name, asset.BrowserDownloadUrl);
                //}

                return true;
            }
        }
        catch
        {
            // Repository not found
        }

        return false;
    }

    private async Task<Release?> GetReleaseAsync(bool prerelease = false)
    {
        var releases = await _releaseClient.GetAll(_repositoryOwner, _repostoryName);
        return releases.FirstOrDefault(x => x.Prerelease == prerelease);
    }

    //public async Task<string> RenderReleaseNotes()
    //{
    //    return Release is null
    //        ? throw new InvalidOperationException()
    //        : await _github.Markdown.RenderRawMarkdown(Release.Body);
    //}
}
