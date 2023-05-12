using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AndroidX.Activity;
using AndroidX.AppCompat.App;
using AndroidX.AppCompat.Widget;
using AndroidX.ConstraintLayout.Widget;
using AndroidX.Core.Content.Resources;
using AndroidX.Core.Widget;
using AndroidX.RecyclerView.Widget;
//using Com.MS.Square.Android.Expandabletextview;
using AniStream.Adapters;
using AniStream.Fragments;
using AniStream.Services;
using AniStream.Utils;
using AniStream.Utils.Extensions;
using AniStream.Utils.Tags;
using Firebase;
using Firebase.Crashlytics;
using Juro.Models.Anime;
using Juro.Providers.Anime;
using Org.Apmem.Tools.Layouts;
using Square.Picasso;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using PopupMenu = AndroidX.AppCompat.Widget.PopupMenu;

namespace AniStream;

[Activity(Label = "EpisodesActivity", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
public class EpisodesActivity : ActivityBase
{
    private readonly IAnimeProvider _client = WeebUtils.AnimeClient;
    private readonly BookmarkManager _bookmarkManager = new("bookmarks");
    private readonly PlayerSettings _playerSettings = new();

    private RecyclerView EpisodesRecyclerView = default!;
    public static List<Episode> Episodes = new();
    private IAnimeInfo Anime = default!;

    private bool IsBooked;
    private bool IsAscending;

    protected override async void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        SetContentView(Resource.Layout.animeinfo);

        FirebaseApp.InitializeApp(this);
        FirebaseCrashlytics.Instance.SetCrashlyticsCollectionEnabled(true);

        Episodes = new();
        SelectorDialogFragment.Cache.Clear();

        _playerSettings.Load();

        var animeString = Intent?.GetStringExtra("anime");
        if (!string.IsNullOrEmpty(animeString))
            Anime = JsonSerializer.Deserialize<AnimeInfo>(animeString)!;

        var animeInfoTitle = FindViewById<TextView>(Resource.Id.animeInfoTitle)!;
        var type = FindViewById<TextView>(Resource.Id.animeInfoType)!;
        var genresFlowLayout = FindViewById<FlowLayout>(Resource.Id.flowLayout)!;
        //var animeInfoSummary = FindViewById<TextView>(Resource.Id.animeInfoSummary)!;
        var released = FindViewById<TextView>(Resource.Id.animeInfoReleased)!;
        var status = FindViewById<TextView>(Resource.Id.animeInfoStatus)!;
        var imageofanime = FindViewById<AppCompatImageView>(Resource.Id.animeInfoImage)!;
        var bookmarkbtn = FindViewById<AppCompatImageView>(Resource.Id.favourite)!;
        var rootLayout = FindViewById<ConstraintLayout>(Resource.Id.animeInfoRoot)!;
        var loading = FindViewById<ContentLoadingProgressBar>(Resource.Id.loading)!;
        var back = FindViewById<AppCompatImageView>(Resource.Id.back)!;
        var menu = FindViewById<AppCompatImageView>(Resource.Id.menu)!;

        //OnBackPressedDispatcher.AddCallback(this,
        //    new BackPressedCallback(true, (s, e) => { }));
        //
        //OnBackPressedDispatcher.OnBackPressed();

        back.Click += (s, e) => { OnBackPressedDispatcher.OnBackPressed(); };

        menu.Click += (s, e) =>
        {
            var popupMenu = new PopupMenu(this, menu);
            popupMenu.Inflate(Resource.Menu.drawer_epsiodes);

            var sortAscending = popupMenu.Menu.FindItem(Resource.Id.sort_ascending)!;
            var sortDescending = popupMenu.Menu.FindItem(Resource.Id.sort_descending)!;

            if (IsAscending)
                sortAscending.SetChecked(true);
            else
                sortDescending.SetChecked(false);

            popupMenu.MenuItemClick += PopupMenu_MenuItemClick;
            popupMenu.Show();
        };

        EpisodesRecyclerView = FindViewById<RecyclerView>(Resource.Id.animeInfoRecyclerView)!;

        animeInfoTitle.Text = Anime.Title;

        if (!string.IsNullOrEmpty(Anime.Image))
        {
            Picasso.Get().Load(Anime.Image).Into(imageofanime);
        }

        loading.Visibility = ViewStates.Visible;
        EpisodesRecyclerView.Visibility = ViewStates.Visible;
        rootLayout.Visibility = ViewStates.Gone;
        //animeInfoSummary.Visibility = ViewStates.Gone;
        imageofanime.Visibility = ViewStates.Gone;

        var bookmarksPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private)!;
        IsAscending = bookmarksPref.GetBoolean("isAscending", false);

        IsBooked = await _bookmarkManager.IsBookmarked(Anime);

        if (IsBooked)
        {
            bookmarkbtn.SetImageDrawable(ResourcesCompat
                .GetDrawable(Resources!, Resource.Drawable.ic_favorite, null));
        }
        else
        {
            bookmarkbtn.SetImageDrawable(ResourcesCompat
                .GetDrawable(Resources!, Resource.Drawable.ic_unfavorite, null));
        }

        bookmarkbtn.Click += async (s, e) =>
        {
            if (IsBooked)
                await _bookmarkManager.RemoveBookmarkAsync(Anime);
            else
                await _bookmarkManager.SaveBookmarkAsync(Anime);

            IsBooked = await _bookmarkManager.IsBookmarked(Anime);

            if (IsBooked)
                bookmarkbtn.SetImageDrawable(ResourcesCompat.GetDrawable(Resources!, Resource.Drawable.ic_favorite, null));
            else
                bookmarkbtn.SetImageDrawable(ResourcesCompat.GetDrawable(Resources!, Resource.Drawable.ic_unfavorite, null));
        };

        var animeInfo = await _client.GetAnimeInfoAsync(Anime.Id);

        if (WeebUtils.AnimeSite == AnimeSites.GogoAnime && string.IsNullOrEmpty(animeInfo.Category))
            animeInfo = await _client.GetAnimeInfoAsync(Anime.Category);

        Anime = animeInfo;

        type.Text = animeInfo.Type?.Replace("Type:", "");
        //animeInfoSummary.Text = animeInfo.Summary?.Replace("Plot Summary:", "");
        released.Text = animeInfo.Released?.Replace("Released:", "");
        //status.Text = animeInfo.Status?.Replace("Status:", "");
        status.Text = animeInfo.Status?.Replace("Status:", "").Split(new[] { "\n" }, StringSplitOptions.None).FirstOrDefault();
        //othernames.Text = animeInfo.OtherNames?.Replace("Other name:", "");

        //TextViewExtensions.MakeTextViewResizable(animeInfoSummary, 2, "See More", true);

        foreach (var genre in animeInfo.Genres)
            genresFlowLayout.AddView(new GenreTag().GetGenreTag(this, genre.Name));

        var episodes = await _client.GetEpisodesAsync(Anime.Id);

        loading.Visibility = ViewStates.Gone;
        rootLayout.Visibility = ViewStates.Visible;
        EpisodesRecyclerView.Visibility = ViewStates.Visible;
        //animeInfoSummary.Visibility = ViewStates.Visible;
        imageofanime.Visibility = ViewStates.Visible;

        Episodes = episodes;

        if (!IsAscending)
            Episodes = Episodes.OrderByDescending(x => x.Number).ToList();
        else
            Episodes = Episodes.OrderBy(x => x.Number).ToList();

        var adapter = new EpisodeRecyclerAdapter(Episodes, this, Anime, _playerSettings);

        //EpisodesRecyclerView.SetLayoutManager(new LinearLayoutManager(this));
        EpisodesRecyclerView.SetLayoutManager(new GridLayoutManager(this, 4));
        EpisodesRecyclerView.HasFixedSize = true;
        EpisodesRecyclerView.DrawingCacheEnabled = true;
        EpisodesRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
        EpisodesRecyclerView.SetItemViewCacheSize(20);
        EpisodesRecyclerView.SetAdapter(adapter);
    }

    private void PopupMenu_MenuItemClick(object? sender, PopupMenu.MenuItemClickEventArgs e)
    {
        if (e.Item!.ItemId == Resource.Id.anime_info_details)
        {
            var builder = new AlertDialog.Builder(this);
            builder.SetTitle("Details");

            builder.SetPositiveButton("OK", (s, e) => { });

            // set the custom layout
            var view = LayoutInflater.Inflate(Resource.Layout.animeinfo_details, null)!;
            builder.SetView(view);

            var animeInfoTitle = view.FindViewById<TextView>(Resource.Id.details_Title)!;
            var type = view.FindViewById<TextView>(Resource.Id.details_Type)!;
            var genresFlowLayout = view.FindViewById<FlowLayout>(Resource.Id.details_FlowLayout)!;
            var plotSummary = view.FindViewById<TextView>(Resource.Id.details_Summary)!;
            var released = view.FindViewById<TextView>(Resource.Id.details_Released)!;
            var otherNames = view.FindViewById<TextView>(Resource.Id.details_OtherNames)!;
            var status = view.FindViewById<TextView>(Resource.Id.details_Status)!;
            var imageofanime = view.FindViewById<AppCompatImageView>(Resource.Id.details_Image)!;

            if (!string.IsNullOrEmpty(Anime.Image))
            {
                Picasso.Get().Load(Anime.Image).Into(imageofanime);
            }

            animeInfoTitle.Text = "Title: " + Anime.Title;
            type.Text = Anime.Type;
            plotSummary.Text = Anime.Summary;
            released.Text = Anime.Released;
            status.Text = Anime.Status;
            otherNames.Text = Anime.OtherNames;

            animeInfoTitle.SetText(TextViewExtensions.MakeSectionOfTextBold(animeInfoTitle.Text, "Title:"), TextView.BufferType.Spannable);
            type.SetText(TextViewExtensions.MakeSectionOfTextBold(type.Text, "Type:"), TextView.BufferType.Spannable);
            //genres.SetText(TextViewExtensions.MakeSectionOfTextBold(genres.Text, "Genre:"), TextView.BufferType.Spannable);
            released.SetText(TextViewExtensions.MakeSectionOfTextBold(released.Text, "Released:"), TextView.BufferType.Spannable);
            status.SetText(TextViewExtensions.MakeSectionOfTextBold(status.Text, "Status:"), TextView.BufferType.Spannable);
            otherNames.SetText(TextViewExtensions.MakeSectionOfTextBold(otherNames.Text, "Other name:"), TextView.BufferType.Spannable);
            plotSummary.SetText(TextViewExtensions.MakeSectionOfTextBold(plotSummary.Text, "Plot Summary:"), TextView.BufferType.Spannable);

            foreach (var genre in Anime.Genres)
                genresFlowLayout.AddView(new GenreTag().GetGenreTag(this, genre.Name));

            builder.SetCancelable(true);
            //Dialog dialog = builder.Create();
            var dialog = builder.Create();
            dialog.SetCanceledOnTouchOutside(true);

            dialog.Show();
        }
        else if (e.Item.ItemId == Resource.Id.sort_ascending)
        {
            IsAscending = true;
            e.Item.SetChecked(true);

            Episodes = Episodes.OrderBy(x => x.Number).ToList();

            if (EpisodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
            {
                episodeRecyclerAdapter.Episodes = Episodes.ToList();
                episodeRecyclerAdapter.NotifyDataSetChanged();
            }

            var isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
            isAscendingPref?.Edit()?.PutBoolean("isAscending", IsAscending)?.Commit();

            InvalidateOptionsMenu();
        }
        else if (e.Item.ItemId == Resource.Id.sort_descending)
        {
            IsAscending = false;
            e.Item.SetChecked(true);

            Episodes = Episodes.OrderByDescending(x => x.Number).ToList();

            if (EpisodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
            {
                episodeRecyclerAdapter.Episodes = Episodes.ToList();
                episodeRecyclerAdapter.NotifyDataSetChanged();
            }

            var isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
            isAscendingPref?.Edit()?.PutBoolean("isAscending", IsAscending)?.Commit();

            InvalidateOptionsMenu();
        }
    }

    protected override void OnRestart()
    {
        base.OnRestart();

        _playerSettings.Load();

        var adapter = new EpisodeRecyclerAdapter(Episodes, this, Anime, _playerSettings);

        //EpisodesRecyclerView.SetLayoutManager(new LinearLayoutManager(this));
        EpisodesRecyclerView.SetLayoutManager(new GridLayoutManager(this, 4));
        EpisodesRecyclerView.HasFixedSize = true;
        EpisodesRecyclerView.DrawingCacheEnabled = true;
        EpisodesRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
        EpisodesRecyclerView.SetItemViewCacheSize(20);
        EpisodesRecyclerView.SetAdapter(adapter);
    }

    public override void OnBackPressed()
    {
        base.OnBackPressed();

        OverridePendingTransition(Resource.Animation.anim_slide_in_bottom, Resource.Animation.anim_slide_out_bottom);
    }
}