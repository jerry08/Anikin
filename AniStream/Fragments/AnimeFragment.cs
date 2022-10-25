using Android.OS;
using Android.Views;
using Android.Widget;
using AndroidX.Fragment.App;
using AndroidX.RecyclerView.Widget;
using AndroidX.SwipeRefreshLayout.Widget;
using AniStream.Adapters;
using AnimeDl;
using AnimeDl.Models;
using AniStream.Utils;
using AnimeDl.Scrapers;

namespace AniStream.Fragments;

public class AnimeFragment : Fragment
{
    private readonly SearchFilter _searchFilter = default!;
    private readonly AnimeClient _client = new(WeebUtils.AnimeSite);

    private int Page = 1;

    private View view = default!;
    private SwipeRefreshLayout swipeRefreshLayout = default!;
    private ProgressBar progressBar = default!;

    public AnimeFragment(SearchFilter searchFilter)
    {
        _searchFilter = searchFilter;
    }

    public static AnimeFragment NewInstance(SearchFilter searchFilter)
    {
        Bundle bundle = new Bundle();
        bundle.PutInt("searchFilter", (int)searchFilter);
        AnimeFragment fragment = new AnimeFragment(searchFilter);
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

    public void Search()
    {
        _client.Search("", _searchFilter, Page);
    }

    public override View OnCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState)
    {
        view = inflater.Inflate(Resource.Layout.dublayout, container, false)!;
        swipeRefreshLayout = view.FindViewById<SwipeRefreshLayout>(Resource.Id.swiperefresh)!;
        RecyclerView mRecyclerView = view.FindViewById<RecyclerView>(Resource.Id.act_recyclerview)!;
        RecyclerView.LayoutManager mLayoutManager = new GridLayoutManager(view.Context, 2);
        mRecyclerView.SetLayoutManager(mLayoutManager);

        swipeRefreshLayout.Refresh += (s, e) =>
        {
            swipeRefreshLayout.Refreshing = true;

            Search();
        };

        progressBar = view.FindViewById<ProgressBar>(Resource.Id.progress3)!;
        progressBar.Visibility = ViewStates.Visible;

        _client.OnAnimesLoaded += (s, e) =>
        {
            Activity.RunOnUiThread(() =>
            {
                if (WeebUtils.AnimeSite == AnimeSites.GogoAnime || WeebUtils.AnimeSite == AnimeSites.Tenshi)
                    Page++;

                var animes = e.Animes;

                if (mRecyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
                {
                    int positionStart = animeRecyclerAdapter.Animes.Count;
                    int itemCount = animeRecyclerAdapter.Animes.Count;

                    animeRecyclerAdapter.Animes.RemoveAll(x => x.Id == "-1");

                    if (WeebUtils.AnimeSite == AnimeSites.GogoAnime)
                        if (animes.Count > 0)
                            animes.Add(new Anime() { Id = "-1" });

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
                    if (WeebUtils.AnimeSite == AnimeSites.GogoAnime)
                        animes.Add(new Anime() { Id = "-1" });

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
            });
        };

        _client.Search("", _searchFilter);

        return view;
    }
}