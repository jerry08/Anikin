using System.Collections.Generic;
using AndroidX.Fragment.App;
using AnimeDl.Scrapers;
using AniStream.Fragments;
using AniStream.Utils;
using Fragment = AndroidX.Fragment.App.Fragment;
using FragmentManager = AndroidX.Fragment.App.FragmentManager;

namespace AniStream.Adapters;

//https://stackoverflow.com/questions/41649956/how-to-reload-fragments-in-viewpager-xamarin
//public class ViewPagerAdapter : FragmentPagerAdapter
public class ViewPagerAdapter : FragmentStatePagerAdapter
{
    private readonly List<Fragment> Fragments = new();

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
            case AnimeSites.AnimePahe:
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Ongoing));
                break;
        }
    }

    public override int Count { get { return Fragments.Count; } }

    public override Fragment GetItem(int position) => Fragments[position];

    public override int GetItemPosition(Java.Lang.Object @object) => base.GetItemPosition(@object);
}