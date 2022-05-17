using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AndroidX.Fragment.App;
using Java.Lang;
using AniStream.Fragments;
using Fragment = AndroidX.Fragment.App.Fragment;
using FragmentManager = AndroidX.Fragment.App.FragmentManager;
using AnimeDl;
using AnimeDl.Scrapers;

namespace AniStream.Adapters
{
    public class ViewPagerAdapter : FragmentPagerAdapter
    {
        List<Fragment> Fragments = new List<Fragment>();

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