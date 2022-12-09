using System;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Views;
using AndroidX.AppCompat.Widget;
using AndroidX.RecyclerView.Widget;
using AndroidX.ViewPager.Widget;
using Newtonsoft.Json;
using AniStream.Utils;
using AniStream.Adapters;
using AnimeDl;
using AnimeDl.Scrapers;
using Google.Android.Material.AppBar;
using Google.Android.Material.Tabs;
using Google.Android.Material.BottomNavigation;
using Google.Android.Material.Navigation;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using Xamarin.Essentials;
using AnimeDl.Scrapers.Events;

namespace AniStream;

[Activity(Label = "@string/app_name", MainLauncher = true, ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public class MainActivity : AndroidX.AppCompat.App.AppCompatActivity, ViewPager.IOnPageChangeListener
{
    private AnimeClient _client = default!;

    private Android.Widget.ProgressBar ProgressBar = default!;
    private SearchView _searchView = default!;
    private IMenuItem? prevMenuItem;
    private AppBarLayout appBarLayout = default!;
    private Android.Widget.LinearLayout noanime = default!;

    private RecyclerView recyclerView = default!;
    private BottomNavigationView bottomNavigationView = default!;
    private ViewPager viewPager = default!;
    private GridLayoutManager gridLayoutManager = default!;

    protected override async void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        Platform.Init(this, savedInstanceState);
        SetContentView(Resource.Layout.activity_main);

        WeebUtils.AppFolderName = Resources!.GetString(Resource.String.app_name)!;
        //WeebUtils.AppFolder = GetExternalFilesDir(null).AbsolutePath;

        var toolbar = FindViewById<Toolbar>(Resource.Id.tool)!;
        SetSupportActionBar(toolbar);

        ProgressBar = FindViewById<Android.Widget.ProgressBar>(Resource.Id.progress2)!;
        recyclerView = FindViewById<RecyclerView>(Resource.Id.recyclerview2)!;
        gridLayoutManager = new GridLayoutManager(this, 2);

        recyclerView.SetLayoutManager(gridLayoutManager);
        recyclerView.Visibility = ViewStates.Gone;

        noanime = FindViewById<Android.Widget.LinearLayout>(Resource.Id.noanime)!;
        bottomNavigationView = FindViewById<BottomNavigationView>(Resource.Id.bottom_navigation)!;
        viewPager = FindViewById<ViewPager>(Resource.Id.viewPager)!;
        appBarLayout = FindViewById<AppBarLayout>(Resource.Id.appbar)!;

        if (!WeebUtils.HasNetworkConnection(this))
        {
            Android.Widget.LinearLayout linearLayout1 = FindViewById<Android.Widget.LinearLayout>(Resource.Id.notvisiblelinearlayout)!;
            linearLayout1.Visibility = ViewStates.Visible;
            viewPager.Visibility = ViewStates.Gone;

            bottomNavigationView.Visibility = ViewStates.Gone;
            appBarLayout.Visibility = ViewStates.Gone;

            return;
        }

        var animeSiteStr = await SecureStorage.GetAsync("AnimeSite");
        if (!string.IsNullOrEmpty(animeSiteStr))
            WeebUtils.AnimeSite = (AnimeSites)Convert.ToInt32(animeSiteStr);
        
        _client = new(WeebUtils.AnimeSite);
        _client.OnAnimesLoaded += Client_OnAnimesLoaded;

        SetupViewPager();
        CreateNotificationChannel();

        var updater = new AppUpdater();
        await updater.CheckAsync(this);
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

    private void Client_OnAnimesLoaded(object? sender, AnimeEventArgs e)
    {
        this.RunOnUiThread(() =>
        {
            var mDataAdapter = new AnimeRecyclerAdapter(this, e.Animes);

            recyclerView.HasFixedSize = true;
            recyclerView.DrawingCacheEnabled = true;
            recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            recyclerView.SetItemViewCacheSize(20);
            recyclerView.SetAdapter(mDataAdapter);
            ProgressBar.Visibility = ViewStates.Gone;
        });
    }

    public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Android.Content.PM.Permission[] grantResults)
    {
        Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        base.OnRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    public override void OnBackPressed()
    {
        var alert = new AlertDialog.Builder(this);
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
            case AnimeSites.Tenshi:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu3);
                break;
            case AnimeSites.Zoro:
                bottomNavigationView.InflateMenu(Resource.Menu.bottommenu4);
                break;
            default:
                break;
        }

        viewPager.CurrentItem = 0;
        bottomNavigationView.Menu.GetItem(0)!.SetChecked(true);

        viewPager.AddOnPageChangeListener(this);

        bottomNavigationView.ItemSelected += (s, e) =>
        {
            switch (e.Item.ItemId)
            {
                //Server1
                case Resource.Id.lastUpdated1:
                    viewPager.CurrentItem = 0;
                    break;
                case Resource.Id.popular1:
                    viewPager.CurrentItem = 1;
                    break;
                case Resource.Id.ongoing1:
                    viewPager.CurrentItem = 2;
                    break;
                case Resource.Id.movies1:
                    viewPager.CurrentItem = 3;
                    break;

                //Server2
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

        _searchView.QueryTextChange += (s, e) =>
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

                _client.CancelSearch();
                _client.Search(e.NewText);
            }
            else
            {
                _client.CancelSearch();

                recyclerView.Visibility = ViewStates.Gone;
                viewPager.Visibility = ViewStates.Visible;
                bottomNavigationView.Visibility = ViewStates.Visible;
                ProgressBar.Visibility = ViewStates.Gone;
            }
        };

        return true;
    }

    private void SetupSources(IMenu menu)
    {
        var gogoanime = menu.FindItem(Resource.Id.source_gogoanime);
        var tenshi = menu.FindItem(Resource.Id.source_tenshi);
        var zoro = menu.FindItem(Resource.Id.source_zoro);

        switch (WeebUtils.AnimeSite)
        {
            case AnimeSites.GogoAnime:
                gogoanime?.SetChecked(true);
                break;
            case AnimeSites.Zoro:
                zoro?.SetChecked(true);
                break;
            case AnimeSites.NineAnime:
                break;
            case AnimeSites.Tenshi:
                tenshi?.SetChecked(true);
                break;
            default:
                break;
        }
    }

    public override bool OnOptionsItemSelected(IMenuItem item)
    {
        int id = item.ItemId;

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
            SaveSelectedSource(id);
        
        return base.OnOptionsItemSelected(item);
    }

    private async void SaveSelectedSource(int id)
    {
        bool shouldUpdateMainView = false;

        var lastAnimeSite = WeebUtils.AnimeSite;

        if (id == Resource.Id.source_gogoanime)
            WeebUtils.AnimeSite = AnimeSites.GogoAnime;
        else if (id == Resource.Id.source_tenshi)
            WeebUtils.AnimeSite = AnimeSites.Tenshi;
        else if (id == Resource.Id.source_zoro)
            WeebUtils.AnimeSite = AnimeSites.Zoro;

        if (lastAnimeSite != WeebUtils.AnimeSite || shouldUpdateMainView)
        {
            await SecureStorage.SetAsync("AnimeSite", ((int)WeebUtils.AnimeSite).ToString());

            _client = new(WeebUtils.AnimeSite);
            _client.OnAnimesLoaded += Client_OnAnimesLoaded;

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