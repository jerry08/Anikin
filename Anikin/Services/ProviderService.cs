using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using CommunityToolkit.Maui.Alerts;
using Httpz;
using Juro;
using Juro.Clients;
using Juro.Utils;
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
            PluginLoader.LoadPlugins(_extractDir);
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
        //var hh1 = AppDomain.CurrentDomain.GetAssemblies().Select(x => x.ToString()).ToList();
        //await App.AlertService.ShowConfirmationAsync("test1", string.Join(Environment.NewLine, hh1));
        //
        //var hh2 = AssemblyEx.GetReferencedAssemblies().ToList().Select(x => x.ToString()).ToList();
        //await App.AlertService.ShowConfirmationAsync("test2", string.Join(Environment.NewLine, hh2));
        //
        //var hh3 = AppDomain.CurrentDomain.GetAssemblies().Select(x => x.ToString()).ToList();
        //await App.AlertService.ShowConfirmationAsync("test3", string.Join(Environment.NewLine, hh3));

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

            PluginLoader.LoadPlugins(_extractDir);

            //var plugins = PluginLoader.GetPlugins();
            //var configs = PluginLoader.GetClientConfigs();

            providers = client.GetAllProviders();

            await Snackbar.Make("Providers loaded successfully").Show();

            var asemb = Assembly.LoadFrom(PluginLoader.GetPlugins()[0].FilePath);

            AppDomain.CurrentDomain.Load(asemb.GetName());

            //var hh1 = AppDomain.CurrentDomain.GetAssemblies().Select(x => x.ToString()).ToList();
            //await App.AlertService.ShowConfirmationAsync("test1", string.Join(Environment.NewLine, hh1));
            //
            //var hh2 = AssemblyEx.GetReferencedAssemblies(asemb).ToList().Select(x => x.ToString()).ToList();
            //await App.AlertService.ShowConfirmationAsync("test2", string.Join(Environment.NewLine, hh2));
            //
            //var pathTest2 = AssemblyEx.GetReferencedAssemblies(asemb).ToList().Select(x => x.Location).ToList();
            //await App.AlertService.ShowConfirmationAsync("ref paths", string.Join(Environment.NewLine, pathTest2));
            
            //var test34 = AssemblyEx.GetReferencedAssemblies(asemb);
            //foreach (var item in test34)
            //{
            //    AppDomain.CurrentDomain.Load(item.GetName());
            //}

            //await App.AlertService.ShowConfirmationAsync("ref paths", string.Join(Environment.NewLine, pathTest2));

            //var hh3 = AppDomain.CurrentDomain.GetAssemblies().Select(x => x.ToString()).ToList();
            //await App.AlertService.ShowConfirmationAsync("test3", string.Join(Environment.NewLine, hh3));

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
