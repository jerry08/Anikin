using System;
using Android.OS;
using Android.Views;
using Android.Widget;
using AndroidX.Fragment.App;
using AndroidX.RecyclerView.Widget;
using AndroidX.SwipeRefreshLayout.Widget;
using AniStream.Adapters;
using AniStream.Utils;
using Juro.Models.Anime;
using Juro.Providers.Anime;

namespace AniStream.Fragments;

/// <summary>
/// Filter applied to a anime search query.
/// </summary>
public enum SearchFilter
{
    /// <summary>
    /// No filter applied.
    /// </summary>
    None,

    /// <summary>
    /// Search by query.
    /// </summary>
    Find,

    /// <summary>
    /// Search for all animes.
    /// </summary>
    AllList,

    /// <summary>
    /// Search for popular animes.
    /// </summary>
    Popular,

    /// <summary>
    /// Search for popular animes.
    /// </summary>
    TopAiring,

    /// <summary>
    /// Search for ongoing animes.
    /// </summary>
    Ongoing,

    /// <summary>
    /// Search for animes in new season.
    /// </summary>
    NewSeason,

    /// <summary>
    /// Search for last updated animes.
    /// </summary>
    LastUpdated,

    /// <summary>
    /// Search for trending animes.
    /// </summary>
    Trending,

    /// <summary>
    /// Search for anime movies.
    /// </summary>
    Movies
}

public class AnimeFragment : Fragment
{
    private readonly IAnimeProvider _client = WeebUtils.AnimeClient;
    private readonly SearchFilter _searchFilter;

    private int Page = 0;

    private View view = default!;
    private RecyclerView mRecyclerView = default!;
    private SwipeRefreshLayout swipeRefreshLayout = default!;
    private ProgressBar progressBar = default!;

    public AnimeFragment(SearchFilter searchFilter)
    {
        _searchFilter = searchFilter;
    }

    public static AnimeFragment NewInstance(SearchFilter searchFilter)
    {
        var bundle = new Bundle();
        bundle.PutInt("searchFilter", (int)searchFilter);
        var fragment = new AnimeFragment(searchFilter);
        fragment.Arguments = bundle;
        return fragment;
    }

    //private void ReadBundle(Bundle bundle)
    //{
    //    if (bundle != null)
    //    {
    //        SearchFilter = (SearchFilter)bundle.GetInt("searchFilter");
    //    }
    //}

    public async void Search()
    {
        if (WeebUtils.AnimeSite is AnimeSites.GogoAnime or AnimeSites.AnimePahe)
            Page++;

        var animes = _client switch
        {
            Gogoanime provider => _searchFilter switch
            {
                SearchFilter.Popular => await provider.GetPopularAsync(Page),
                SearchFilter.NewSeason => await provider.GetNewSeasonAsync(Page),
                SearchFilter.LastUpdated => await provider.GetLastUpdatedAsync(Page),
                _ => throw new NotImplementedException(),
            },
            Zoro provider => _searchFilter switch
            {
                SearchFilter.Popular => await provider.GetPopularAsync(Page),
                SearchFilter.NewSeason => await provider.GetRecentlyAddedAsync(Page),
                SearchFilter.TopAiring => await provider.GetAiringAsync(Page),
                _ => throw new NotImplementedException(),
            },
            AnimePahe provider => _searchFilter switch
            {
                SearchFilter.TopAiring => await provider.GetAiringAsync(Page),
                _ => throw new NotImplementedException(),
            },
            NineAnime provider => _searchFilter switch
            {
                SearchFilter.Popular => await provider.GetPopularAsync(Page),
                SearchFilter.LastUpdated => await provider.GetLastUpdatedAsync(Page),
                _ => throw new NotImplementedException(),
            },
            _ => throw new NotImplementedException(),
        };

        if (mRecyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
        {
            var positionStart = animeRecyclerAdapter.Animes.Count;
            var itemCount = animeRecyclerAdapter.Animes.Count;

            animeRecyclerAdapter.Animes.RemoveAll(x => x.Id == "-1");

            if ((WeebUtils.AnimeSite == AnimeSites.GogoAnime
                || WeebUtils.AnimeSite == AnimeSites.AnimePahe)
                && animes.Count > 0)
            {
                animes.Add(new AnimeInfo() { Id = "-1" });
            }

            animeRecyclerAdapter.Animes.AddRange(animes);
            mRecyclerView.SetItemViewCacheSize(animeRecyclerAdapter.Animes.Count + 5);
            //animeRecyclerAdapter.NotifyDataSetChanged();

            itemCount = animeRecyclerAdapter.Animes.Count;

            //animeRecyclerAdapter.NotifyItemRangeChanged(positionStart, itemCount);
            //animeRecyclerAdapter.NotifyItemRangeInserted(positionStart, animes.Count); //OR
            animeRecyclerAdapter.NotifyItemRangeChanged(positionStart - 1, itemCount);
        }
        else
        {
            if (WeebUtils.AnimeSite == AnimeSites.GogoAnime
                || WeebUtils.AnimeSite == AnimeSites.AnimePahe)
            {
                animes.Add(new AnimeInfo() { Id = "-1" });
            }

            //var mDataAdapter = new AnimeRecyclerAdapter(view.Context, animes, this);
            var mDataAdapter = new AnimeRecyclerAdapter(Activity, animes, this);

            mRecyclerView.HasFixedSize = true;
            mRecyclerView.DrawingCacheEnabled = true;
            mRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            mRecyclerView.SetItemViewCacheSize(20);
            mRecyclerView.SetAdapter(mDataAdapter);
        }

        progressBar.Visibility = ViewStates.Gone;

        swipeRefreshLayout.Refreshing = false;
    }

    public override View OnCreateView(LayoutInflater? inflater, ViewGroup? container, Bundle? savedInstanceState)
    {
        view = inflater?.Inflate(Resource.Layout.dublayout, container, false)!;
        swipeRefreshLayout = view.FindViewById<SwipeRefreshLayout>(Resource.Id.swiperefresh)!;
        mRecyclerView = view.FindViewById<RecyclerView>(Resource.Id.act_recyclerview)!;
        RecyclerView.LayoutManager mLayoutManager = new GridLayoutManager(view.Context, 2);
        mRecyclerView.SetLayoutManager(mLayoutManager);

        swipeRefreshLayout.Refresh += (s, e) =>
        {
            swipeRefreshLayout.Refreshing = true;

            Search();
        };

        progressBar = view.FindViewById<ProgressBar>(Resource.Id.progress3)!;
        progressBar.Visibility = ViewStates.Visible;

        Search();

        return view;
    }
}