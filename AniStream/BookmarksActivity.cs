using System.Collections.Generic;
using System.Linq;
using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Views;
using AndroidX.AppCompat.Widget;
using AndroidX.RecyclerView.Widget;
using AniStream.Adapters;
using AniStream.Utils;
using Juro.Models.Anime;
using Microsoft.Maui.ApplicationModel;

namespace AniStream;

[Activity(Label = "@string/app_name", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public class BookmarksActivity : AndroidX.AppCompat.App.AppCompatActivity
{
    private readonly BookmarkManager _bookmarkManager = new("bookmarks");

    private List<AnimeInfo> animes = new();
    private Android.Widget.ProgressBar ProgressBar = default!;
    private SearchView SearchView = default!;

    private RecyclerView recyclerView = default!;
    private GridLayoutManager gridLayoutManager = default!;

    protected override async void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        Platform.Init(this, savedInstanceState);
        SetContentView(Resource.Layout.activity_bookmark_anime);

        var toolbar = FindViewById<Toolbar>(Resource.Id.tool);
        SetSupportActionBar(toolbar);

        ProgressBar = FindViewById<Android.Widget.ProgressBar>(Resource.Id.progress3)!;
        recyclerView = FindViewById<RecyclerView>(Resource.Id.animelistrecyclerview)!;
        gridLayoutManager = new GridLayoutManager(this, 2);

        recyclerView.SetLayoutManager(gridLayoutManager);
        recyclerView.Visibility = ViewStates.Visible;

        animes = await _bookmarkManager.GetBookmarks();

        var mDataAdapter = new AnimeRecyclerAdapter(this, animes);

        recyclerView.HasFixedSize = true;
        recyclerView.DrawingCacheEnabled = true;
        recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
        recyclerView.SetItemViewCacheSize(20);
        recyclerView.SetAdapter(mDataAdapter);
        ProgressBar.Visibility = ViewStates.Gone;
    }

    public override bool OnCreateOptionsMenu(IMenu? menu)
    {
        MenuInflater.Inflate(Resource.Menu.drawer_bookmark, menu);
        var search = menu!.FindItem(Resource.Id.action_search2)!;

        SearchView = search.ActionView.JavaCast<SearchView>()!;
        SearchView.Clickable = true;

        SearchView.QueryTextChange += (s, e) =>
        {
            if (string.IsNullOrEmpty(e.NewText))
                return;

            if (recyclerView.GetAdapter() is AnimeRecyclerAdapter adapter)
            {
                adapter.Animes = animes
                    .Where(x => x.Title.ToLower().Contains(e.NewText.ToLower()))
                    .ToList();

                adapter.NotifyDataSetChanged();
            }
        };

        return true;
    }

    public override bool OnOptionsItemSelected(IMenuItem item)
    {
        var id = item.ItemId;

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

    private void ClearBookmarks()
    {
        var alert = new AlertDialog.Builder(this, Resource.Style.DialogTheme);
        alert.SetMessage("Are you sure you want to clear all?");
        alert.SetPositiveButton("Yes", async (s, e) =>
        {
            await _bookmarkManager.RemoveAllBookmarksAsync();

            var animes = await _bookmarkManager.GetBookmarks();

            var mDataAdapter = new AnimeRecyclerAdapter(this, animes);

            recyclerView.HasFixedSize = true;
            recyclerView.DrawingCacheEnabled = true;
            recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            recyclerView.SetItemViewCacheSize(20);
            recyclerView.SetAdapter(mDataAdapter);
        });

        alert.SetNegativeButton("Cancel", (s, e) => { });
        alert.SetCancelable(true);

        var dialog = alert.Create()!;
        dialog.Show();
    }

    protected override async void OnRestart()
    {
        base.OnRestart();

        var animes = await _bookmarkManager.GetBookmarks();

        if (recyclerView?.GetAdapter() is AnimeRecyclerAdapter adapter)
        {
            if (animes.Count != adapter.Animes.Count)
            {
                var mDataAdapter = new AnimeRecyclerAdapter(this, animes);

                recyclerView.HasFixedSize = true;
                recyclerView.DrawingCacheEnabled = true;
                recyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                recyclerView.SetItemViewCacheSize(20);
                recyclerView.SetAdapter(mDataAdapter);
            }
        }
    }

    public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Permission[] grantResults)
    {
        Platform.OnRequestPermissionsResult(requestCode, permissions, grantResults);

        base.OnRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    public override void OnBackPressed()
    {
        base.OnBackPressed();

        OverridePendingTransition(Resource.Animation.anim_slide_in_right, Resource.Animation.anim_slide_out_right);
    }
}