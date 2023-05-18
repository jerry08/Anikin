using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Microsoft.Maui.ApplicationModel;

namespace AniStream.Utils;

public class PackageInstallPermission
{
    private readonly Activity _activity;

    private const int PackageInstallRequestCode = 2238;

    private readonly TaskCompletionSource<bool> _tcs = new();

    public PackageInstallPermission(Activity context)
    {
        _activity = context;
    }

    public bool CheckStatus()
        => _activity.PackageManager!.CanRequestPackageInstalls();

    public async Task<bool> RequestAsync()
    {
        if (_activity.PackageManager!.CanRequestPackageInstalls())
            return true;

        var intent = new Intent(
            Android.Provider.Settings.ActionManageUnknownAppSources,
            Android.Net.Uri.Parse("package:" + AppInfo.Current.PackageName)
        );

        _activity.StartActivityForResult(intent, PackageInstallRequestCode);

        return await _tcs.Task;
    }

    public void OnActivityResult(int requestCode, Result resultCode, Intent? data)
    {
        if (requestCode == PackageInstallRequestCode)
        {
            _tcs.TrySetResult(_activity.PackageManager!.CanRequestPackageInstalls());
        }
    }
}