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
#if WINDOWS
using Snackbar = CommunityToolkit.Maui.Alerts.Toast;
#endif

namespace Anikin.Services;

public class ProviderService
{
    private readonly string _zipPath;
    private readonly string _extractDir;

    public ProviderService()
    {
        var dir = OperatingSystem.IsWindows()
            ? AppDomain.CurrentDomain.BaseDirectory
            : FileSystem.AppDataDirectory;

        _zipPath = Path.Combine(dir, "providers_temp.zip");
        _extractDir = Path.Combine(dir, "providers_temp2");
    }

    public void Initialize()
    {
        if (!Directory.Exists(_extractDir))
            return;

        try
        {
            Locator.Instance.Load(_extractDir);
        }
        catch
        {
            try
            {
                Directory.Delete(_extractDir, true);
            }
            catch { }
        }
    }

    public async Task<bool> DownloadAsync(string repoUrl)
    {
        try
        {
            var urlParts = repoUrl.Split("/");
            if (urlParts.Length < 2)
            {
                await App.AlertService.ShowAlertAsync("Error", "Invalid GitHub url");
                return false;
            }

            var pair = urlParts.TakeLast(2);
            var repositoryOwner = pair.ElementAtOrDefault(0);
            var repostoryName = pair.ElementAtOrDefault(1);

            if (string.IsNullOrEmpty(repositoryOwner) || string.IsNullOrEmpty(repositoryOwner))
            {
                await App.AlertService.ShowAlertAsync("Error", "Invalid GitHub url");
                return false;
            }

            var github = new GitHubClient(new ProductHeaderValue(repostoryName + "-Download"));
            var releaseClient = github.Repository.Release;

            var release = await releaseClient.GetLatest(repositoryOwner, repostoryName);
            if (release is null)
                return false;

            await Snackbar.Make("Download started").Show();

            if (Directory.Exists(_extractDir))
                Directory.Delete(_extractDir, true);

            var downloader = new Downloader();
            await downloader.DownloadAsync(release.Assets[0].BrowserDownloadUrl, _zipPath);

            System.IO.Compression.ZipFile.ExtractToDirectory(_zipPath, _extractDir);

            await Snackbar.Make($"Download & extraction completed. Path: '{_extractDir}'").Show();

            var client = new AnimeClient();
            var providers = client.GetAllProviders();

            var locator = new Locator();
            locator.Load(_extractDir);

            //var modules = locator.GetModules();
            //var configs = locator.GetClientConfigs();

            providers = client.GetAllProviders();

            await Snackbar.Make("Providers loaded successfully").Show();

            return true;
        }
        catch (Exception ex)
        {
            // Repository not found

            App.AlertService.ShowAlert("Error", ex.ToString());
            return false;
        }
    }
}
