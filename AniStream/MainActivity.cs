using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Database.Sqlite;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Webkit;
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
using Google.Android.Material.Snackbar;

namespace AniStream
{
    [Activity(Label = "@string/app_name", Theme = "@style/AppTheme", MainLauncher = true, ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class MainActivity : AndroidX.AppCompat.App.AppCompatActivity, ViewPager.IOnPageChangeListener
    {
        public AnimeScraper AnimeScraper = new AnimeScraper();
        List<Anime> Animes = new List<Anime>();
        Android.Widget.ProgressBar ProgressBar;
        SearchView SearchView;
        IMenuItem prevMenuItem;
        AppBarLayout appBarLayout;
        Android.Widget.LinearLayout noanime;

        RecyclerView recyclerView;
        BottomNavigationView bottomNavigationView;
        ViewPager viewPager;
        GridLayoutManager gridLayoutManager;

        protected override void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            Xamarin.Essentials.Platform.Init(this, savedInstanceState);
            SetContentView(Resource.Layout.activity_main);

            //string linkTest = "https://goload.pro/encrypt-ajax.php?id=WZ+Ui79hxLDJVOPtxtMXDw==&title=Platinum+End+Episode+24&mip=0.0.0.0&refer=none&ch=d41d8cd98f00b204e9800998ecf8427e&token2=OUq9vFyXSPXc8cfUlTEuKQ&expires2=1652731176&op=1&alias=MTgzMDY3";
            //
            //string encHtmlData = await Http.GetHtmlAsync(linkTest,
            //    new WebHeaderCollection()
            //    {
            //        { "X-Requested-With", "XMLHttpRequest" },
            //        //{ "Referer", "https://gogoanime.sk/" },
            //    });
            //
            //var builder =
            //    new AlertDialog.Builder(this, Android.App.AlertDialog.ThemeDeviceDefaultLight);
            //builder.SetMessage(encHtmlData);
            //builder.Show();

            WeebUtils.AppFolderName = Resources.GetString(Resource.String.app_name);
            //WeebUtils.AppFolder = GetExternalFilesDir(null).AbsolutePath;

            Toolbar toolbar = FindViewById<Toolbar>(Resource.Id.tool);
            SetSupportActionBar(toolbar);

            ProgressBar = FindViewById<Android.Widget.ProgressBar>(Resource.Id.progress2);
            recyclerView = FindViewById<RecyclerView>(Resource.Id.recyclerview2);
            gridLayoutManager = new GridLayoutManager(this, 2);

            recyclerView.SetLayoutManager(gridLayoutManager);
            recyclerView.Visibility = ViewStates.Gone;

            noanime = FindViewById<Android.Widget.LinearLayout>(Resource.Id.noanime);
            bottomNavigationView = FindViewById<BottomNavigationView>(Resource.Id.bottom_navigation);
            viewPager = FindViewById<ViewPager>(Resource.Id.viewPager);
            appBarLayout = FindViewById<AppBarLayout>(Resource.Id.appbar);

            if (!WeebUtils.HaveNetworkConnection(ApplicationContext))
            {
                Android.Widget.LinearLayout linearLayout1 = FindViewById<Android.Widget.LinearLayout>(Resource.Id.notvisiblelinearlayout);
                linearLayout1.Visibility = ViewStates.Visible;
                viewPager.Visibility = ViewStates.Gone;

                bottomNavigationView.Visibility = ViewStates.Gone;
                appBarLayout.Visibility = ViewStates.Gone;
            }

            ViewPagerAdapter viewPagerAdapter;
            viewPagerAdapter = new ViewPagerAdapter(SupportFragmentManager);
            viewPager.OffscreenPageLimit = 3;
            viewPager.SetPageTransformer(true, new DepthPageTransformer());
            viewPager.Adapter = viewPagerAdapter;

            switch (AnimeScraper.CurrentSite)
            {
                case AnimeSites.TwistMoe:
                    bottomNavigationView.InflateMenu(Resource.Menu.bottommenu2);
                    break;
                case AnimeSites.GogoAnime:
                    bottomNavigationView.InflateMenu(Resource.Menu.bottommenu2);
                    break;
                default:
                    break;
            }

            viewPager.CurrentItem = 0;
            bottomNavigationView.Menu.GetItem(0).SetChecked(true);

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

            AnimeScraper = new AnimeScraper();
            AnimeScraper.OnAnimesLoaded += (s, e) =>
            {
                AnimeRecyclerAdapter mDataAdapter = new AnimeRecyclerAdapter(this, e.Animes);

                recyclerView.HasFixedSize = true;
                recyclerView.DrawingCacheEnabled = true;
                recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                recyclerView.SetItemViewCacheSize(20);
                recyclerView.SetAdapter(mDataAdapter);
                ProgressBar.Visibility = ViewStates.Gone;
            };
        }

        public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Android.Content.PM.Permission[] grantResults)
        {
            Xamarin.Essentials.Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

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

            alert.SetNegativeButton("Cancel", (s, e) =>
            {

            });

            alert.SetCancelable(false);
            var dialog = alert.Create();
            dialog.Show();
        }

        public override bool OnCreateOptionsMenu(IMenu menu)
        {
            MenuInflater.Inflate(Resource.Menu.drawer, menu);
            IMenuItem search = menu.FindItem(Resource.Id.action_search);
            IMenuItem bookmark = menu.FindItem(Resource.Id.bookmark_menu);
            
            IMenuItem donate = menu.FindItem(Resource.Id.donate);
            IMenuItem settings = menu.FindItem(Resource.Id.settings);
            IMenuItem animeGenres = menu.FindItem(Resource.Id.animeGenres);

            donate.SetVisible(false);
            animeGenres.SetVisible(false);

            SearchView = search.ActionView.JavaCast<SearchView>();
            SearchView.Clickable = true;

            SearchView.QueryTextChange += (s, e) =>
            {
                noanime.Visibility = ViewStates.Gone;

                if (e.NewText.Length >= 3)
                {
                    ProgressBar.Visibility = ViewStates.Visible;
                    recyclerView.Visibility = ViewStates.Visible;
                    viewPager.Visibility = ViewStates.Gone;
                    bottomNavigationView.Visibility = ViewStates.Gone;

                    AnimeScraper.CancelSearch();
                    AnimeScraper.Search(e.NewText);
                }
                else
                {
                    AnimeScraper.CancelSearch();

                    recyclerView.Visibility = ViewStates.Gone;
                    viewPager.Visibility = ViewStates.Visible;
                    bottomNavigationView.Visibility = ViewStates.Visible;
                    ProgressBar.Visibility = ViewStates.Gone;
                }
            };

            return true;
        }

        public override bool OnOptionsItemSelected(IMenuItem item)
        {
            int id = item.ItemId;

            if (id == Resource.Id.settings)
            {
                Intent intent = new Intent(this, typeof(SettingsActivity));
                StartActivity(intent);
                return false;
            }
            else if (id == Resource.Id.bookmark_menu)
            {
                Intent i = new Intent(this, typeof(BookmarksActivity));
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

            return base.OnOptionsItemSelected(item);
        }

        private void FabOnClick(object sender, EventArgs eventArgs)
        {
            View view = (View) sender;
            Snackbar.Make(view, "Replace with your own action", Snackbar.LengthLong)
                .SetAction("Action", (View.IOnClickListener)null).Show();
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
                bottomNavigationView.Menu.GetItem(0).SetChecked(false);

            bottomNavigationView.Menu.GetItem(position).SetChecked(true);
            prevMenuItem = bottomNavigationView.Menu.GetItem(position);
        }
    }
}