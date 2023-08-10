using System.Collections.Generic;
using AndroidX.Fragment.App;
using AniStream.Fragments;
using AniStream.Utils;
using Juro.Models.Anime;
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
            case AnimeSites.Kaido:
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Popular));
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.NewSeason));
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.TopAiring));
                break;
            case AnimeSites.AnimePahe:
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.TopAiring));
                break;
            case AnimeSites.Aniwave:
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Popular));
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.LastUpdated));
                break;
            case AnimeSites.OtakuDesu:
                Fragments.Add(AnimeFragment.NewInstance(SearchFilter.Find));
                break;
        }
    }

    public override int Count { get { return Fragments.Count; } }

    public override Fragment GetItem(int position) => Fragments[position];

    public override int GetItemPosition(Java.Lang.Object @object) => base.GetItemPosition(@object);
}