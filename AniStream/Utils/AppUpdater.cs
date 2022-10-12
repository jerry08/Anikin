using System;
using System.Linq;
using System.Threading.Tasks;
using AndroidX.Fragment.App;
using Octokit;
using Xamarin.Essentials;

namespace AniStream.Utils;

public class AppUpdater
{
    private IReleasesClient _releaseClient;
    private GitHubClient Github;

    private string RepositoryOwner = "jerry08";
    private string RepostoryName = "Anistream";
    private Release LatestRelease;

    public AppUpdater()
    {
        Github = new GitHubClient(new ProductHeaderValue(RepostoryName + @"-UpdateCheck"));
        _releaseClient = Github.Repository.Release;
    }

    public async Task<bool> CheckAsync(FragmentActivity activity)
    {
        var packageInfo = activity.PackageManager.GetPackageInfo(activity.PackageName, 0);

        bool dontShow = false;
        var dontShowStr = await SecureStorage.GetAsync($"dont_ask_for_update_{packageInfo.VersionName}");
        if (!string.IsNullOrEmpty(dontShowStr))
        {
            dontShow = Convert.ToBoolean(dontShowStr);
        }

        if (dontShow)
            return false;

        //var repo = activity.GetString(Resource.String.repo);

        //var github = new GitHubClient(new ProductHeaderValue("jerry08"));
        //
        //var tt = github.Repository.Get("jerry08", "AniStream");
        //tt.Wait();
        //
        //var gs = tt.Result;

        var releases = await _releaseClient.GetAll(RepositoryOwner, RepostoryName);
        var latestRelease = releases.FirstOrDefault();

        var latestVersionName = new Version(latestRelease.Name);
        var currentVersionName = new Version(packageInfo.VersionName);

        if (currentVersionName < latestVersionName)
        {
            var builder = new Android.App.AlertDialog.Builder(activity,
                Android.App.AlertDialog.ThemeDeviceDefaultLight);
            builder.SetTitle("Update available");
            builder.SetPositiveButton("Download", (s, e) =>
            {
                var asset = latestRelease.Assets.FirstOrDefault();

                var downloader = new Downloader(activity);
                downloader.Download(asset.Name, asset.BrowserDownloadUrl);
            });

            builder.SetNegativeButton("OK", (s, e) =>
            {

            });

            builder.Show();

            return true;
        }

        return false;
    }

    public async Task<string> RenderReleaseNotes()
    {
        if (LatestRelease == null)
            throw new InvalidOperationException();

        return await Github.Markdown.RenderRawMarkdown(LatestRelease.Body);
    }
}