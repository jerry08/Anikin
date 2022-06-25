using System.Collections.Generic;
using AndroidX.Fragment.App;
using AniStream.Fragments;
using Fragment = AndroidX.Fragment.App.Fragment;
using FragmentManager = AndroidX.Fragment.App.FragmentManager;
using AnimeDl.Scrapers;

namespace AniStream.Adapters
{
    public class ViewPagerAdapter : FragmentPagerAdapter
    {
        private readonly List<Fragment> Fragments = new List<Fragment>();

        public ViewPagerAdapter(FragmentManager fm) : base(fm)
        {            
            Fragments.Add(AnimeFragment.NewInstance(SearchType.Popular));
            Fragments.Add(AnimeFragment.NewInstance(SearchType.NewSeason));
            Fragments.Add(AnimeFragment.NewInstance(SearchType.LastUpdated));
        }

        public override int Count { get { return Fragments.Count; } }

        public override Fragment GetItem(int position)
        {
            return Fragments[position];
        }

        public override int GetItemPosition(Java.Lang.Object @object)
        {
            return base.GetItemPosition(@object);
        }
    }
}