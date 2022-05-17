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
        SearchType SearchType;
        AnimeScraper AnimeScraper = new AnimeScraper();
        SwipeRefreshLayout swipeRefreshLayout;
        View view;

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
            AnimeScraper.Search("", SearchType);
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

            //Dub();

            /*switch (SearchType)
            {
                case SearchType.Find:
                    break;
                case SearchType.Popular:
                    Popular();
                    break;
                case SearchType.NewSeason:
                    NewSeason();
                    break;
                case SearchType.LastUpdated:
                    break;
                case SearchType.Trending:
                    break;
                default:
                    break;
            }*/

            AnimeScraper.OnAnimesLoaded += (s, e) =>
            {
                if (AnimeScraper.CurrentSite == AnimeSites.GogoAnime)
                    AnimeScraper.Page++;

                var animes = e.Animes;

                if (mRecyclerView.GetAdapter() is AnimeRecyclerAdapter animeRecyclerAdapter)
                {
                    int positionStart = animeRecyclerAdapter.Animes.Count;
                    int itemCount = animeRecyclerAdapter.Animes.Count;

                    animeRecyclerAdapter.Animes.RemoveAll(x => x.Id == -1);

                    if (AnimeScraper.CurrentSite == AnimeSites.GogoAnime)
                    {
                        if (animes.Count > 0)
                            animes.Add(new Anime() { Id = -1 });
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
                    if (AnimeScraper.CurrentSite == AnimeSites.GogoAnime)
                    {
                        animes.Add(new Anime() { Id = -1 });
                    }

                    //AnimeRecyclerAdapter mDataAdapter = new AnimeRecyclerAdapter(view.Context, animes, this);
                    AnimeRecyclerAdapter mDataAdapter = new AnimeRecyclerAdapter(Activity, animes, this);

                    mRecyclerView.HasFixedSize = true;
                    mRecyclerView.DrawingCacheEnabled = true;
                    mRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                    mRecyclerView.SetItemViewCacheSize(20);
                    mRecyclerView.SetAdapter(mDataAdapter);
                }

                progressBar.Visibility = ViewStates.Gone;

                swipeRefreshLayout.Refreshing = false;
            };

            AnimeScraper.Search("", SearchType);

            return view;
            //return base.OnCreateView(inflater, container, savedInstanceState);
        }

        /*void Dub()
        {
            if (initial == 1)
            {
                progressBar = view.FindViewById<ProgressBar>(Resource.Id.progress);
                progressBar.Visibility = ViewStates.Visible;
                //     swipeRefreshLayout.setRefreshing(true);
            }

            RecyclerView mRecyclerView = view.FindViewById<RecyclerView>(Resource.Id.act_recyclerview);
            DataAdapter mDataAdapter = new DataAdapter(view.Context, dubAnimeList, dubSiteLink, dubImageLink, dubEpisodeList, getActivity());
            RecyclerView.LayoutManager mLayoutManager = new GridLayoutManager(view.Context, 2);

            mRecyclerView.HasFixedSize = true;
            mRecyclerView.DrawingCacheEnabled = true;
            mRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
            mRecyclerView.SetItemViewCacheSize(20);
            mRecyclerView.SetLayoutManager(mLayoutManager);
            mRecyclerView.SetAdapter(mDataAdapter);
            initial = 0;
            progressBar.Visibility = ViewStates.Gone;
            swipeRefreshLayout.Refreshing = false;
        }*/
    }
}