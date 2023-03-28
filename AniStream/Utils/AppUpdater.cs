using System;
using System.Linq;
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
    private Release LatestRelease = default!;

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
            var releases = await _releaseClient.GetAll(_repositoryOwner, _repostoryName);
            var latestRelease = releases.FirstOrDefault()!;

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
                    var asset = latestRelease.Assets.FirstOrDefault()!;

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

    public async Task<string> RenderReleaseNotes()
    {
        return LatestRelease is null ? throw new InvalidOperationException() : await _github.Markdown.RenderRawMarkdown(LatestRelease.Body);
    }
}