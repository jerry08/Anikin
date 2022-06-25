using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Webkit;
using Android.Widget;
using AndroidX.Fragment.App;
using AndroidX.RecyclerView.Widget;
using AndroidX.SwipeRefreshLayout.Widget;
using AniStream.Adapters;
using AnimeDl;
using AnimeDl.Scrapers;

namespace AniStream.Fragments
{
    public class AnimeFragment : Fragment
    {
        private readonly SearchType SearchType;
        private readonly AnimeClient _client = new AnimeClient();
        private SwipeRefreshLayout swipeRefreshLayout;
        private View view;
        private int Page = 1;

        //public bool SupportsPagination = false;

        public AnimeFragment(SearchType searchType)
        {
            SearchType = searchType;
        }

        public static AnimeFragment NewInstance(SearchType searchType)
        {
            Bundle bundle = new Bundle();
            bundle.PutInt("searchType", (int)searchType);
            AnimeFragment dubFragment = new AnimeFragment(searchType);
            dubFragment.Arguments = bundle;
            return dubFragment;
        }

        //private void ReadBundle(Bundle bundle)
        //{
        //    if (bundle != null)
        //    {
        //        SearchType = (SearchType)bundle.GetInt("searchType");
        //    }
        //}

        private ProgressBar progressBar;

        public void Search()
        {
            _client.Search("", SearchType, Page);
        }

        public override View OnCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState)
        {
            view = inflater.Inflate(Resource.Layout.dublayout, container, false);
            swipeRefreshLayout = view.FindViewById<SwipeRefreshLayout>(Resource.Id.swiperefresh);
            RecyclerView mRecyclerView = view.FindViewById<RecyclerView>(Resource.Id.act_recyclerview);
            RecyclerView.LayoutManager mLayoutManager = new GridLayoutManager(view.Context, 2);
            mRecyclerView.SetLayoutManager(mLayoutManager);

            swipeRefreshLayout.Refresh += (s, e) =>
            {
                swipeRefreshLayout.Refreshing = true;

                Search();
            };

            progressBar = view.FindViewById<ProgressBar>(Resource.Id.progress3);
            progressBar.Visibility = ViewStates.Visible;

            _client.OnAnimesLoaded += (s, e) =>
            {
                if (_client.Site == AnimeSites.GogoAnime)
                {
                    Page++;
                }

                var animes = e.Animes;

                if (mRecyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
                {
                    int positionStart = animeRecyclerAdapter.Animes.Count;
                    int itemCount = animeRecyclerAdapter.Animes.Count;

                    animeRecyclerAdapter.Animes.RemoveAll(x => x.Id == -1);

                    if (_client.Site == AnimeSites.GogoAnime)
                    {
                        if (animes.Count > 0)
                        {
                            animes.Add(new Anime() { Id = -1 });
                        }
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
                    if (_client.Site == AnimeSites.GogoAnime)
                    {
                        animes.Add(new Anime() { Id = -1 });
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
            };

            _client.Search("", SearchType);

            return view;
        }
    }
}