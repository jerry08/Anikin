using System.Text.RegularExpressions;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using AndroidX.AppCompat.App;
using AniStream.Services;

namespace AniStream;

[IntentFilter(
    actions: new[] { Intent.ActionView },
    Label = "Anilist Login for AniStream",
    Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
    DataSchemes = new[] { "anistream" },
    //DataScheme = "anistream",
    DataHosts = new[] { "anilist" }
    //DataHost = "anilist"
    //DataPathPatterns = new[] { "/.*/.*" },
    //DataPathPrefix = "/anime/"
)]

[Activity(LaunchMode = LaunchMode.SingleTask, MainLauncher = false, Exported = true, ExcludeFromRecents = true)]
public class LoginActivity : AppCompatActivity
{
    private readonly SettingsService _settingsService = new();

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        //var tt1 = new Uri("anistream://anilist");
        //var tt2 = new Uri("anistream.anilist");

        var data = Intent?.Data?.ToString();
        if (!string.IsNullOrWhiteSpace(data))
        {
            var regex = new Regex("""(?<=access_token=).+(?=&token_type)""");
            var token = regex.Match(data);

            _settingsService.Load();
            _settingsService.AnilistAccessToken = token.Value;
            _settingsService.Save();

            Microsoft.Maui.Controls.Application.Current.MainPage = new AppShell();
        }

        Finish();

        //Shell.Current.SendBackButtonPressed();
    }
}