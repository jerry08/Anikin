using System;
using System.Collections.Generic;
using System.Linq;
using Android;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using AndroidX.AppCompat.Widget;
using AndroidX.RecyclerView.Widget;
using AnimeDl;
using Newtonsoft.Json;
using AniStream.Utils;
using AniStream.Adapters;
using AnimeDl.Models;

namespace AniStream
{
    [Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class BookmarksActivity : AndroidX.AppCompat.App.AppCompatActivity
    {
        List<Anime> animes;
        Android.Widget.ProgressBar ProgressBar;
        SearchView SearchView;

        RecyclerView recyclerView;
        GridLayoutManager gridLayoutManager;

        BookmarkManager BookmarkManager;

        protected override async void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            Xamarin.Essentials.Platform.Init(this, savedInstanceState);
            SetContentView(Resource.Layout.activity_bookmark_anime);

            Toolbar toolbar = FindViewById<Toolbar>(Resource.Id.tool);
            SetSupportActionBar(toolbar);

            ProgressBar = FindViewById<Android.Widget.ProgressBar>(Resource.Id.progress3);
            recyclerView = FindViewById<RecyclerView>(Resource.Id.animelistrecyclerview);
            gridLayoutManager = new GridLayoutManager(this, 2);

            recyclerView.SetLayoutManager(gridLayoutManager);
            recyclerView.Visibility = ViewStates.Visible;

            BookmarkManager = new BookmarkManager("bookmarks");

            animes = await BookmarkManager.GetBookmarks();

            AnimeRecyclerAdapter mDataAdapter = new AnimeRecyclerAdapter(this, animes);

            recyclerView.HasFixedSize = true;
            recyclerView.DrawingCacheEnabled = true;
            recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            recyclerView.SetItemViewCacheSize(20);
            recyclerView.SetAdapter(mDataAdapter);
            ProgressBar.Visibility = ViewStates.Gone;
        }

        public override bool OnCreateOptionsMenu(IMenu menu)
        {
            MenuInflater.Inflate(Resource.Menu.drawer_bookmark, menu);
            IMenuItem search = menu.FindItem(Resource.Id.action_search2);

            SearchView = search.ActionView.JavaCast<SearchView>();
            SearchView.Clickable = true;

            SearchView.QueryTextChange += (s, e) =>
            {
                if (string.IsNullOrEmpty(e.NewText))
                {
                    return;
                }

                if (recyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
                {
                    animeRecyclerAdapter.Animes = animes
                        .Where(x => x.Title.ToLower().Contains(e.NewText.ToLower()))
                        .ToList();

                    animeRecyclerAdapter.NotifyDataSetChanged();
                }
            };

            return true;
        }

        public override bool OnOptionsItemSelected(IMenuItem item)
        {
            int id = item.ItemId;

            if (id == Resource.Id.settings)
            {
                //Intent intent = new Intent(getApplicationContext(), Settings.class);
                //StartActivity(intent);
                return false;
            }
            else if (id == Resource.Id.clearAllBookmarks)
            {
                ClearBookmarks();
                return false;
            }

            return base.OnOptionsItemSelected(item);
        }

        private async void ClearBookmarks()
        {
            BookmarkManager.RemoveAllBookmarks();

            var animes = await BookmarkManager.GetBookmarks();

            var mDataAdapter = new AnimeRecyclerAdapter(this, animes);

            recyclerView.HasFixedSize = true;
            recyclerView.DrawingCacheEnabled = true;
            recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            recyclerView.SetItemViewCacheSize(20);
            recyclerView.SetAdapter(mDataAdapter);
        }

        protected override async void OnRestart()
        {
            base.OnRestart();

            var animes = await BookmarkManager.GetBookmarks();

            if (recyclerView != null && recyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
            {
                if (animes.Count != animeRecyclerAdapter.Animes.Count)
                {
                    AnimeRecyclerAdapter mDataAdapter = new AnimeRecyclerAdapter(this, animes);

                    recyclerView.HasFixedSize = true;
                    recyclerView.DrawingCacheEnabled = true;
                    recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                    recyclerView.SetItemViewCacheSize(20);
                    recyclerView.SetAdapter(mDataAdapter);
                }
            }
        }

        public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Android.Content.PM.Permission[] grantResults)
        {
            Xamarin.Essentials.Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

            base.OnRequestPermissionsResult(requestCode, permissions, grantResults);
        }

        public override void OnBackPressed()
        {
            base.OnBackPressed();

            OverridePendingTransition(Resource.Animation.anim_slide_in_right, Resource.Animation.anim_slide_out_right);
        }
    }
}