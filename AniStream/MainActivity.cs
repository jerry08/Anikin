using System;
using System.Threading;
using System.Threading.Tasks;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Graphics;
using Android.Graphics.Drawables;
using Android.OS;
using Android.Runtime;
using Android.Views;
using AndroidX.AppCompat.Widget;
using AndroidX.Core.App;
using AndroidX.Core.Content;
using AndroidX.RecyclerView.Widget;
using AndroidX.ViewPager.Widget;
using AniStream.Adapters;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using Firebase;
using Firebase.Crashlytics;
using Google.Android.Material.AppBar;
using Google.Android.Material.BottomNavigation;
using Jerro.Maui.GoogleClient;
using Juro.Models.Anime;
using Juro.Providers.Anime;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;

namespace AniStream;

[Activity(Label = "@string/app_name", MainLauncher = true, ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public class MainActivity : ActivityBase, ViewPager.IOnPageChangeListener
{
    private readonly static int PostNotificationsRequestCode = 1005;

    private IAnimeProvider _client = default!;

    public CancellationTokenSource CancellationTokenSource { get; set; } = new();

    private Android.Widget.ProgressBar ProgressBar = default!;
    private SearchView _searchView = default!;
    private IMenuItem? prevMenuItem;
    private AppBarLayout appBarLayout = default!;
    private Android.Widget.LinearLayout noanime = default!;

    private Toolbar _toolbar = default!;
    private RecyclerView recyclerView = default!;
    private BottomNavigationView bottomNavigationView = default!;
    private ViewPager viewPager = default!;
    private GridLayoutManager gridLayoutManager = default!;

    protected override async void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        Platform.Init(this, savedInstanceState);
        SetContentView(Resource.Layout.activity_main);

        FirebaseApp.InitializeApp(this);
        FirebaseCrashlytics.Instance.SetCrashlyticsCollectionEnabled(true);

        GoogleClientManager.Initialize(
            this,
            null,
            "1018117642382-c6avui7h23fdfd4rgc20mo70bn4rljob.apps.googleusercontent.com"
        );

        _toolbar = FindViewById<Toolbar>(Resource.Id.toolbar)!;
        SetSupportActionBar(_toolbar);

        _toolbar.NavigationClick += delegate
        {
            var intent = new Intent(this, typeof(SettingsActivity));
            StartActivity(intent);
        };

        SetHomeProfilePhotoAsync();

        CrossGoogleClient.Current.OnLogin += async (s, e) => await DownloadProfilePhotoAsync();

        CrossGoogleClient.Current.OnLogout += (s, e) =>
        {
            var filePath = System.IO.Path.Combine(
                FileSystem.Current.AppDataDirectory,
                "profilephoto.jpeg"
            );

            if (System.IO.File.Exists(filePath))
                System.IO.File.Delete(filePath);

            SetHomeProfilePhotoAsync();
        };

        ProgressBar = FindViewById<Android.Widget.ProgressBar>(Resource.Id.progress2)!;
        recyclerView = FindViewById<RecyclerView>(Resource.Id.recyclerview2)!;
        gridLayoutManager = new GridLayoutManager(this, 2);

        recyclerView.SetLayoutManager(gridLayoutManager);
        recyclerView.Visibility = ViewStates.Gone;

        noanime = FindViewById<Android.Widget.LinearLayout>(Resource.Id.noanime)!;
        bottomNavigationView = FindViewById<BottomNavigationView>(Resource.Id.bottom_navigation)!;
        viewPager = FindViewById<ViewPager>(Resource.Id.viewPager)!;
        appBarLayout = FindViewById<AppBarLayout>(Resource.Id.appbar)!;

        if (!WeebUtils.IsOnline())
        {
            var linearLayout1 = FindViewById<Android.Widget.LinearLayout>(Resource.Id.notvisiblelinearlayout)!;
            linearLayout1.Visibility = ViewStates.Visible;
            viewPager.Visibility = ViewStates.Gone;

            bottomNavigationView.Visibility = ViewStates.Gone;
            appBarLayout.Visibility = ViewStates.Gone;

            return;
        }

        var animeSiteStr = await SecureStorage.GetAsync("AnimeSite");
        if (!string.IsNullOrEmpty(animeSiteStr))
            WeebUtils.AnimeSite = (AnimeSites)Convert.ToInt32(animeSiteStr);

        _client = WeebUtils.AnimeClient;

        SetupViewPager();

        if (Build.VERSION.SdkInt > BuildVersionCodes.S)
        {
            if (ContextCompat.CheckSelfPermission(this,
                Manifest.Permission.PostNotifications)
                != Permission.Granted)
            {
                ActivityCompat.RequestPermissions(this,
                    new string[] { Manifest.Permission.PostNotifications },
                    PostNotificationsRequestCode);
            }
        }

        //StartActivity(new Intent(Android.Provider.Settings.ActionManageUnknownAppSources));
        //StartActivity(new Intent(Android.Provider.Settings.ActionManageUnknownAppSources), Uri.parse("AppInfo.PackageName"));

        CreateNotificationChannel();

        var updater = new AppUpdater();
        await updater.CheckAsync(this);

        //if (this.IsPackageInstalled("com.ira.ffmpeg"))
        //{
        //    var intent = new Intent();
        //    intent.PutExtra("command", "-version");
        //
        //    intent.SetComponent(new ComponentName("com.ira.ffmpeg", "com.ira.ffmpeg.FFmpegService"));
        //    //StartService(intent);
        //    this.StartForegroundService(intent);
        //}

        try
        {
            await SecureStorage.SetAsync("RepositoryOwner", "jerry08");
            await SecureStorage.SetAsync("RepositoryName", "Juro");
        }
        catch { }
    }

    public void CreateNotificationChannel()
    {
        if (Build.VERSION.SdkInt < BuildVersionCodes.O)
        {
            // Notification channels are new in API 26 (and not a part of the
            // support library). There is no need to create a notification
            // channel on older versions of Android.
            return;
        }

        var channelId = $"{PackageName}.general";

        var channel = new NotificationChannel(channelId, "General", NotificationImportance.Low)
        {
            Description = "General"
        };

        channel.EnableLights(true);
        channel.SetShowBadge(true);

        var notificationManager = (NotificationManager?)GetSystemService(Android.Content.Context.NotificationService);
        notificationManager?.CreateNotificationChannel(channel);
    }

    public async void SetHomeProfilePhotoAsync()
    {
        SupportActionBar?.SetDisplayHomeAsUpEnabled(false);

        var filePath = System.IO.Path.Combine(
            FileSystem.Current.AppDataDirectory,
            "profilephoto.jpeg"
        );

        if (!System.IO.File.Exists(filePath))
            await DownloadProfilePhotoAsync();

        if (!System.IO.File.Exists(filePath))
            return;

        var bytes = await System.IO.File.ReadAllBytesAsync(filePath);

        var image = new BitmapDrawable(
            Resources,
            BitmapFactory.DecodeByteArray(bytes, 0, bytes.Length)
        );

        image.Bitmap = image.Bitmap!.GetRoundedCornerBitmap(100);

        SupportActionBar?.SetDisplayHomeAsUpEnabled(true);

        _toolbar.NavigationIcon = image;
    }

    public async Task DownloadProfilePhotoAsync()
    {
        var filePath = System.IO.Path.Combine(
            FileSystem.Current.AppDataDirectory,
            "profilephoto.jpeg"
        );

        if (System.IO.File.Exists(filePath))
            System.IO.File.Delete(filePath);

        if (!CrossGoogleClient.Current.IsLoggedIn)
        {
            using var fileStream = System.IO.File.Create(filePath);
            var stream = Assets!.Open("blank_profile_picture.png");
            await stream.CopyToAsync(fileStream);
            return;
        }

        var url = CrossGoogleClient.Current.CurrentUser.Picture;

        var http = Http.ClientProvider();
        var bytes = await http.GetByteArrayAsync(url);

        await System.IO.File.WriteAllBytesAsync(filePath, bytes);

        var image = new BitmapDrawable(
            Resources,
            BitmapFactory.DecodeByteArray(bytes, 0, bytes.Length)
        );

        image.Bitmap = image.Bitmap!.GetRoundedCornerBitmap(100);

        _toolbar.NavigationIcon = image;
    }

    public override void OnBackPressed()
    {
        var alert = new AlertDialog.Builder(this, Resource.Style.DialogTheme);
        alert.SetMessage("Are you sure you want to exit?");
        alert.SetPositiveButton("Yes", (s, e) =>
        {
            FinishAffinity();
            Process.KillProcess(Process.MyPid());

            base.OnBackPressed();
        });

        alert.SetNegativeButton("Cancel", (s, e) => { });

        alert.SetCancelable(false);
        var dialog = alert.Create();
        dialog.Show();
    }

    private void SetupViewPager()
    {
        var viewPagerAdapter = new ViewPagerAdapter(SupportFragmentManager);
        viewPager.OffscreenPageLimit = 3;
        viewPager.SetPageTransformer(true, new DepthPageTransformer());
        viewPager.Adapter = viewPagerAdapter;

        bottomNavigationView.Menu.Clear();

        switch (WeebUtils.AnimeSite)
        {
            case AnimeSites.GogoAnime:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu2);
                break;
            case AnimeSites.Kaido:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu4);
                break;
            case AnimeSites.AnimePahe:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu5);
                break;
            case AnimeSites.Aniwave:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu_aniwave);
                break;
            case AnimeSites.OtakuDesu:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu_otakudesu);
                break;
        }

        viewPager.CurrentItem = 0;
        bottomNavigationView.Menu.GetItem(0)!.SetChecked(true);

        viewPager.AddOnPageChangeListener(this);

        bottomNavigationView.ItemSelected += (s, e) =>
        {
            switch (e.Item.ItemId)
            {
                case Resource.Id.Popular:
                    viewPager.CurrentItem = 0;
                    break;
                case Resource.Id.New:
                    viewPager.CurrentItem = 1;
                    break;
                case Resource.Id.LastUpdated:
                    viewPager.CurrentItem = 2;
                    break;
            }
        };
    }

    public override bool OnCreateOptionsMenu(IMenu? menu)
    {
        MenuInflater.Inflate(Resource.Menu.drawer, menu);
        var search = menu!.FindItem(Resource.Id.action_search)!;
        var bookmark = menu.FindItem(Resource.Id.bookmark_menu);

        var donate = menu.FindItem(Resource.Id.donate);
        var settings = menu.FindItem(Resource.Id.settings);
        var animeGenres = menu.FindItem(Resource.Id.animeGenres);

        donate?.SetVisible(false);
        animeGenres?.SetVisible(false);

        SetupSources(menu);

        _searchView = search.ActionView.JavaCast<SearchView>()!;
        _searchView.Clickable = true;

        _searchView.QueryTextChange += async (s, e) =>
        {
            noanime.Visibility = ViewStates.Gone;

            //if (e.NewText.Length >= 3)
            if (e.NewText?.Length >= 1)
            {
                if (recyclerView.GetAdapter() is AnimeRecyclerAdapter adapter)
                {
                    adapter.Animes.Clear();
                    adapter.NotifyDataSetChanged();
                }

                ProgressBar.Visibility = ViewStates.Visible;
                recyclerView.Visibility = ViewStates.Visible;
                viewPager.Visibility = ViewStates.Gone;
                bottomNavigationView.Visibility = ViewStates.Gone;

                CancellationTokenSource.Cancel();
                CancellationTokenSource = new();

                try
                {
                    var animes = await _client.SearchAsync(e.NewText, CancellationTokenSource.Token);

                    var mDataAdapter = new AnimeRecyclerAdapter(this, animes);

                    recyclerView.HasFixedSize = true;
                    recyclerView.DrawingCacheEnabled = true;
                    recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                    recyclerView.SetItemViewCacheSize(20);
                    recyclerView.SetAdapter(mDataAdapter);
                    ProgressBar.Visibility = ViewStates.Gone;
                }
                catch
                {
                    // Ignore operation cancelled
                }
            }
            else
            {
                CancellationTokenSource.Cancel();
                CancellationTokenSource = new();

                recyclerView.Visibility = ViewStates.Gone;
                viewPager.Visibility = ViewStates.Visible;
                bottomNavigationView.Visibility = ViewStates.Visible;
                ProgressBar.Visibility = ViewStates.Gone;
            }
        };

        return true;
    }

    private async void SetupSources(IMenu menu)
    {
        var animeSiteStr = await SecureStorage.GetAsync("AnimeSite");
        if (!string.IsNullOrEmpty(animeSiteStr))
            WeebUtils.AnimeSite = (AnimeSites)Convert.ToInt32(animeSiteStr);

        var gogoanime = menu.FindItem(Resource.Id.source_gogoanime);
        var kaido = menu.FindItem(Resource.Id.source_kaido);
        var animepahe = menu.FindItem(Resource.Id.source_animepahe);
        var aniwave = menu.FindItem(Resource.Id.source_aniwave);
        var otakudesu = menu.FindItem(Resource.Id.source_otakudesu);

        switch (WeebUtils.AnimeSite)
        {
            case AnimeSites.GogoAnime:
                gogoanime?.SetChecked(true);
                break;
            case AnimeSites.Kaido:
                kaido?.SetChecked(true);
                break;
            case AnimeSites.AnimePahe:
                animepahe?.SetChecked(true);
                break;
            case AnimeSites.Aniwave:
                aniwave?.SetChecked(true);
                break;
            case AnimeSites.OtakuDesu:
                otakudesu?.SetChecked(true);
                break;
        }
    }

    public override bool OnOptionsItemSelected(IMenuItem item)
    {
        var id = item.ItemId;

        if (id == Resource.Id.settings)
        {
            var intent = new Intent(this, typeof(SettingsActivity));
            StartActivity(intent);
            return false;
        }
        else if (id == Resource.Id.recently_watched)
        {
            var intent = new Intent(this, typeof(RecentlyWatchedActivity));
            StartActivity(intent);
            return false;
        }
        else if (id == Resource.Id.bookmark_menu)
        {
            var i = new Intent(this, typeof(BookmarksActivity));
            StartActivity(i);
            OverridePendingTransition(Resource.Animation.anim_slide_in_left, Resource.Animation.anim_slide_out_left);

            return false;
        }
        else if (id == Resource.Id.donate)
        {
            //Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.anistream.xyz/donate.html"));
            //startActivity(browserIntent);
            return false;
        }
        else
        {
            SaveSelectedSource(id);
        }

        return base.OnOptionsItemSelected(item);
    }

    private async void SaveSelectedSource(int id)
    {
        var lastAnimeSite = WeebUtils.AnimeSite;

        if (id == Resource.Id.source_gogoanime)
            WeebUtils.AnimeSite = AnimeSites.GogoAnime;
        else if (id == Resource.Id.source_kaido)
            WeebUtils.AnimeSite = AnimeSites.Kaido;
        else if (id == Resource.Id.source_animepahe)
            WeebUtils.AnimeSite = AnimeSites.AnimePahe;
        else if (id == Resource.Id.source_aniwave)
            WeebUtils.AnimeSite = AnimeSites.Aniwave;
        else if (id == Resource.Id.source_otakudesu)
            WeebUtils.AnimeSite = AnimeSites.OtakuDesu;

        if (lastAnimeSite != WeebUtils.AnimeSite)
        {
            await SecureStorage.SetAsync("AnimeSite", ((int)WeebUtils.AnimeSite).ToString());

            _client = WeebUtils.AnimeClient;

            InvalidateOptionsMenu();
            SetupViewPager();
        }
    }

    public override void OverridePendingTransition(int enterAnim, int exitAnim)
    {
        base.OverridePendingTransition(enterAnim, exitAnim);
    }

    public void OnPageScrollStateChanged(int state)
    {
    }

    public void OnPageScrolled(int position, float positionOffset, int positionOffsetPixels)
    {
    }

    public void OnPageSelected(int position)
    {
        if (prevMenuItem != null)
            prevMenuItem.SetChecked(false);
        else
            bottomNavigationView.Menu.GetItem(0)!.SetChecked(false);

        bottomNavigationView.Menu.GetItem(position)!.SetChecked(true);
        prevMenuItem = bottomNavigationView.Menu.GetItem(position);
    }
}