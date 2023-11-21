using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Maui.Alerts;
using Httpz;
using Juro;
using Juro.Clients;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;
using Octokit;

namespace Anikin.Services;

public class ProviderService
{
    private readonly IReleasesClient _releaseClient;
    private readonly GitHubClient _github;

    private readonly string _repositoryOwner = "jerry08";
    private readonly string _repostoryName = "Juro";

    public ProviderService()
    {
        _github = new GitHubClient(new ProductHeaderValue(_repostoryName + "-Download"));
        _releaseClient = _github.Repository.Release;
    }

    public async Task<bool> DownloadAsync()
    {
        try
        {
            var release = await GetReleaseAsync();
            if (release is null)
                return false;

            await Snackbar.Make("Download started").Show();

            var zipPath = Path.Combine(FileSystem.AppDataDirectory, "providers_temp.zip");
            var extractPath = Path.Combine(FileSystem.AppDataDirectory, "providers_temp2");

            if (Directory.Exists(extractPath))
                Directory.Delete(extractPath, true);

            var downloader = new Downloader();
            await downloader.DownloadAsync(release.Assets[0].BrowserDownloadUrl, zipPath);

            System.IO.Compression.ZipFile.ExtractToDirectory(zipPath, extractPath);

            await Snackbar.Make("Download & extraction completed").Show();

            var client = new AnimeClient();
            var providers = client.GetAllProviders();

            var locator = new Locator();
            locator.Load(extractPath);

            var modules = locator.GetModules();
            var configs = locator.GetClientConfigs();

            providers = client.GetAllProviders();

            await Snackbar.Make("Providers loaded successfully").Show();

            return true;
        }
        catch (Exception ex)
        {
            // Repository not found

            App.AlertService.ShowAlert("Error", ex.ToString());
        }

        return false;
    }

    private async Task<Release?> GetReleaseAsync(bool prerelease = false)
    {
        var releases = await _releaseClient.GetAll(_repositoryOwner, _repostoryName);
        return releases.FirstOrDefault(x => x.Prerelease == prerelease);
    }
}
