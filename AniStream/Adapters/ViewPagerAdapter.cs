using System.Collections.Generic;
using AndroidX.Fragment.App;
using Fragment = AndroidX.Fragment.App.Fragment;
using FragmentManager = AndroidX.Fragment.App.FragmentManager;
using AniStream.Fragments;
using AniStream.Utils;
using AnimeDl.Scrapers;

namespace AniStream.Adapters
{
    //https://stackoverflow.com/questions/41649956/how-to-reload-fragments-in-viewpager-xamarin
    //public class ViewPagerAdapter : FragmentPagerAdapter
    public class ViewPagerAdapter : FragmentStatePagerAdapter
    {
        private readonly List<Fragment> Fragments = new List<Fragment>();

        public ViewPagerAdapter(FragmentManager fm) : base(fm)
        {
            switch (WeebUtils.AnimeSite)
            {
                case AnimeSites.GogoAnime:
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Popular));
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.NewSeason));
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.LastUpdated));
                    break;
                case AnimeSites.Zoro:
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Popular));
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.NewSeason));
                    break;
                case AnimeSites.NineAnime:
                    break;
                case AnimeSites.Tenshi:
                    Fragments.Add(AnimeFragment.NewInstance(SearchFilter.NewSeason));
                    break;
                default:
                    break;
            }
        }

        public override int Count { get { return Fragments.Count; } }

        public override Fragment GetItem(int position) => Fragments[position];
        

        public override int GetItemPosition(Java.Lang.Object @object)=> base.GetItemPosition(@object);
        
    }
}
