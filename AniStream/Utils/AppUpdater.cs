using System;
using System.Threading.Tasks;
using AndroidX.Fragment.App;
using AniStream.Utils.Downloading;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;
using Octokit;

namespace AniStream.Utils;

public class AppUpdater
{
    private readonly IReleasesClient _releaseClient;
    private readonly GitHubClient _github;

    private readonly string _repositoryOwner = "jerry08";
    private readonly string _repostoryName = "Anistream";

    public AppUpdater()
    {
        _github = new GitHubClient(new ProductHeaderValue(_repostoryName + "-UpdateCheck"));
        _releaseClient = _github.Repository.Release;
    }

    public async Task<bool> CheckAsync(FragmentActivity activity)
    {
        var dontShow = false;
        var dontShowStr = await SecureStorage.GetAsync($"dont_ask_for_update_{AppInfo.Current.VersionString}");
        if (!string.IsNullOrEmpty(dontShowStr))
            dontShow = Convert.ToBoolean(dontShowStr);

        if (dontShow)
            return false;

        try
        {
            var latestRelease = await _releaseClient.GetLatest(_repositoryOwner, _repostoryName);

            var latestVersionName = new Version(latestRelease.Name);
            var currentVersionName = AppInfo.Current.Version;

            if (currentVersionName < latestVersionName)
            {
                var builder = new Android.App.AlertDialog.Builder(
                    activity,
                    Android.App.AlertDialog.ThemeDeviceDefaultLight
                );

                builder.SetTitle("Update available");
                builder.SetPositiveButton("Download", (s, e) =>
                {
                    var asset = latestRelease.Assets[0];

                    var downloader = new Downloader(activity);
                    downloader.Download(asset.Name, asset.BrowserDownloadUrl);
                });

                builder.SetNegativeButton("OK", (s, e) => { });

                builder.Show();

                return true;
            }
        }
        catch
        {
            // Repository not found
        }

        return false;
    }
}