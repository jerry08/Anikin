using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Media;
using Android.OS;
using Android.Runtime;
using Android.Text;
using Android.Views;
using Android.Widget;
using AndroidX.ConstraintLayout.Widget;
using AndroidX.Core.View;
using AndroidX.Core.Widget;
using AndroidX.RecyclerView.Widget;
using Google.Android.Material.AppBar;
using Newtonsoft.Json;
using Square.Picasso;
using AniStream.Utils;
using AniStream.Adapters;
using AnimeDl;
using AndroidX.AppCompat.App;
using AniStream.Utils.Extensions;
using Org.Apmem.Tools.Layouts;
using AniStream.Utils.Tags;
using AndroidX.AppCompat.Widget;
using AndroidX.Core.Content.Resources;
//using Com.MS.Square.Android.Expandabletextview;
using PopupMenu = AndroidX.AppCompat.Widget.PopupMenu;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using AnimeDl.Models;

namespace AniStream
{
    [Activity(Label = "EpisodesActivity", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class EpisodesActivity : AppCompatActivity
    {
        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);
        public event EventHandler<EventArgs> OnPermissionsResult;

        private RecyclerView episodesRecyclerView;
        private List<Episode> Episodes = new List<Episode>();
        private Anime anime;

        private bool IsBooked;
        private bool IsAscending;

        private readonly BookmarkManager _bookmarkManager = new BookmarkManager("bookmarks");

        protected override async void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            
            SetContentView(Resource.Layout.animeinfo);

            string animeString = Intent.GetStringExtra("anime");
            if (!string.IsNullOrEmpty(animeString))
            {
                anime = JsonConvert.DeserializeObject<Anime>(animeString);
            }
            
            var animeInfoTitle = FindViewById<TextView>(Resource.Id.animeInfoTitle);
            var type = FindViewById<TextView>(Resource.Id.animeInfoType);
            var genresFlowLayout = FindViewById<FlowLayout>(Resource.Id.flowLayout);
            //var animeInfoSummary = FindViewById<TextView>(Resource.Id.animeInfoSummary);
            var released = FindViewById<TextView>(Resource.Id.animeInfoReleased);
            var status = FindViewById<TextView>(Resource.Id.animeInfoStatus);
            var imageofanime = FindViewById<AppCompatImageView>(Resource.Id.animeInfoImage);
            var bookmarkbtn = FindViewById<AppCompatImageView>(Resource.Id.favourite);
            var rootLayout = FindViewById<ConstraintLayout>(Resource.Id.animeInfoRoot);
            var loading = FindViewById<ContentLoadingProgressBar>(Resource.Id.loading);
            var back = FindViewById<AppCompatImageView>(Resource.Id.back);
            var menu = FindViewById<AppCompatImageView>(Resource.Id.menu);

            back.Click += (s, e) =>
            {
                OnBackPressed();
            };

            menu.Click += (s, e) =>
            {
                PopupMenu popupMenu = new PopupMenu(this, menu);
                popupMenu.Inflate(Resource.Menu.drawer_epsiodes);

                IMenuItem sortAscending = popupMenu.Menu.FindItem(Resource.Id.sort_ascending);
                IMenuItem sortDescending = popupMenu.Menu.FindItem(Resource.Id.sort_descending);

                if (IsAscending)
                {
                    sortAscending.SetChecked(true);
                }
                else
                {
                    sortDescending.SetChecked(false);
                }

                popupMenu.MenuItemClick += PopupMenu_MenuItemClick;
                popupMenu.Show();
            };

            episodesRecyclerView = FindViewById<RecyclerView>(Resource.Id.animeInfoRecyclerView);

            animeInfoTitle.Text = anime.Title;

            if (!string.IsNullOrEmpty(anime.Image))
            {
                Picasso.Get().Load(anime.Image).Into(imageofanime);
            }

            loading.Visibility = ViewStates.Visible;
            episodesRecyclerView.Visibility = ViewStates.Visible;
            rootLayout.Visibility = ViewStates.Gone;
            //animeInfoSummary.Visibility = ViewStates.Gone;
            imageofanime.Visibility = ViewStates.Gone;

            ISharedPreferences bookmarksPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
            IsAscending = bookmarksPref.GetBoolean("isAscending", false);

            IsBooked = await _bookmarkManager.IsBookmarked(anime);

            if (IsBooked)
            {
                bookmarkbtn.SetImageDrawable(ResourcesCompat
                    .GetDrawable(Resources, Resource.Drawable.ic_favorite, null));
            }
            else
            {
                bookmarkbtn.SetImageDrawable(ResourcesCompat
                    .GetDrawable(Resources, Resource.Drawable.ic_unfavorite, null));
            }

            bookmarkbtn.Click += async (s, e) =>
            {
                if (IsBooked)
                {
                    _bookmarkManager.RemoveBookmark(anime);
                }
                else
                {
                    _bookmarkManager.SaveBookmark(anime);
                }

                IsBooked = await _bookmarkManager.IsBookmarked(anime);

                if (IsBooked)
                {
                    bookmarkbtn.SetImageDrawable(ResourcesCompat
                        .GetDrawable(Resources, Resource.Drawable.ic_favorite, null));
                }
                else
                {
                    bookmarkbtn.SetImageDrawable(ResourcesCompat
                        .GetDrawable(Resources, Resource.Drawable.ic_unfavorite, null));
                }
            };

            _client.OnEpisodesLoaded += (s, e) =>
            {
                loading.Visibility = ViewStates.Gone;
                rootLayout.Visibility = ViewStates.Visible;
                episodesRecyclerView.Visibility = ViewStates.Visible;
                //animeInfoSummary.Visibility = ViewStates.Visible;
                imageofanime.Visibility = ViewStates.Visible;

                Episodes = e.Episodes;

                if (!IsAscending)
                {
                    Episodes = Episodes.OrderByDescending(x => x.Number).ToList();
                }
                else
                {
                    Episodes = Episodes.OrderBy(x => x.Number).ToList();
                }

                anime = e.Anime;

                type.Text = e.Anime.Type?.Replace("Type:", "");
                //animeInfoSummary.Text = e.Anime.Summary?.Replace("Plot Summary:", "");
                released.Text = e.Anime.Released?.Replace("Released:", "");
                status.Text = e.Anime.Status?.Replace("Status:", "");
                //othernames.Text = e.Anime.OtherNames?.Replace("Other name:", "");

                //TextViewExtensions.MakeTextViewResizable(animeInfoSummary, 2, "See More", true);

                foreach (var genre in e.Anime.Genres)
                {
                    genresFlowLayout.AddView(new GenreTag().GetGenreTag(this, genre.Name));
                }

                var adapter = new EpisodeRecyclerAdapter(Episodes, this, anime);

                episodesRecyclerView.SetLayoutManager(new LinearLayoutManager(this));
                episodesRecyclerView.HasFixedSize = true;
                episodesRecyclerView.DrawingCacheEnabled = true;
                episodesRecyclerView.DrawingCacheQuality = DrawingCacheQuality.High;
                episodesRecyclerView.SetItemViewCacheSize(20);
                episodesRecyclerView.SetAdapter(adapter);
            };

            _client.GetEpisodes(anime);
        }

        private void PopupMenu_MenuItemClick(object sender, PopupMenu.MenuItemClickEventArgs e)
        {
            if (e.Item.ItemId == Resource.Id.anime_info_details)
            {
                AlertDialog.Builder builder = new AlertDialog.Builder(this);
                builder.SetTitle("Details");

                builder.SetPositiveButton("OK", (s, e) => 
                { 
                });

                // set the custom layout
                View view = LayoutInflater.Inflate(Resource.Layout.animeinfo_details, null);
                builder.SetView(view);

                var animeInfoTitle = view.FindViewById<TextView>(Resource.Id.details_Title);
                var type = view.FindViewById<TextView>(Resource.Id.details_Type);
                var genresFlowLayout = view.FindViewById<FlowLayout>(Resource.Id.details_FlowLayout);
                var plotSummary = view.FindViewById<TextView>(Resource.Id.details_Summary);
                var released = view.FindViewById<TextView>(Resource.Id.details_Released);
                var otherNames = view.FindViewById<TextView>(Resource.Id.details_OtherNames);
                var status = view.FindViewById<TextView>(Resource.Id.details_Status);
                var imageofanime = view.FindViewById<AppCompatImageView>(Resource.Id.details_Image);

                if (!string.IsNullOrEmpty(anime.Image))
                {
                    Picasso.Get().Load(anime.Image).Into(imageofanime);
                }

                animeInfoTitle.Text = "Title: " + anime.Title;
                type.Text = anime.Type;
                plotSummary.Text = anime.Summary;
                released.Text = anime.Released;
                status.Text = anime.Status;
                otherNames.Text = anime.OtherNames;

                animeInfoTitle.SetText(TextViewExtensions.MakeSectionOfTextBold(animeInfoTitle.Text, "Title:"), TextView.BufferType.Spannable);
                type.SetText(TextViewExtensions.MakeSectionOfTextBold(type.Text, "Type:"), TextView.BufferType.Spannable);
                //genres.SetText(TextViewExtensions.MakeSectionOfTextBold(genres.Text, "Genre:"), TextView.BufferType.Spannable);
                released.SetText(TextViewExtensions.MakeSectionOfTextBold(released.Text, "Released:"), TextView.BufferType.Spannable);
                status.SetText(TextViewExtensions.MakeSectionOfTextBold(status.Text, "Status:"), TextView.BufferType.Spannable);
                otherNames.SetText(TextViewExtensions.MakeSectionOfTextBold(otherNames.Text, "Other name:"), TextView.BufferType.Spannable);
                plotSummary.SetText(TextViewExtensions.MakeSectionOfTextBold(plotSummary.Text, "Plot Summary:"), TextView.BufferType.Spannable);

                foreach (var genre in anime.Genres)
                {
                    genresFlowLayout.AddView(new GenreTag().GetGenreTag(this, genre.Name));
                }

                builder.SetCancelable(true);
                //Dialog dialog = builder.Create();
                AlertDialog dialog = builder.Create();
                dialog.SetCanceledOnTouchOutside(true);

                dialog.Show();
            }
            else if (e.Item.ItemId == Resource.Id.sort_ascending)
            {
                IsAscending = true;
                e.Item.SetChecked(true);

                Episodes = Episodes.OrderBy(x => x.Number).ToList();

                if (episodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
                {
                    episodeRecyclerAdapter.Episodes = Episodes.ToList();
                    episodeRecyclerAdapter.NotifyDataSetChanged();
                }

                ISharedPreferences isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
                isAscendingPref.Edit().PutBoolean("isAscending", IsAscending).Commit();

                InvalidateOptionsMenu();
            }
            else if (e.Item.ItemId == Resource.Id.sort_descending)
            {
                IsAscending = false;
                e.Item.SetChecked(true);

                Episodes = Episodes.OrderByDescending(x => x.Number).ToList();

                if (episodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
                {
                    episodeRecyclerAdapter.Episodes = Episodes.ToList();
                    episodeRecyclerAdapter.NotifyDataSetChanged();
                }

                ISharedPreferences isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
                isAscendingPref.Edit().PutBoolean("isAscending", IsAscending).Commit();

                InvalidateOptionsMenu();
            }
        }

        public override void OnRequestPermissionsResult(int requestCode, string[] permissions, [GeneratedEnum] Permission[] grantResults)
        {
            switch (requestCode)
            {
                case 1:
                    {
                        // If request is cancelled, the result arrays are empty.
                        if (grantResults.Length > 0 
                            && grantResults[0] == Permission.Granted)
                        {
                            //ContinueInitialize();
                            //StartActivity(Intent);
                        }
                        else
                        {
                            //Toast.makeText(MainActivity.this, "Permission denied to read your External storage", Toast.LENGTH_SHORT).show();
                            
                            //Finish();
                        }
                    }
                    break;

                    // other 'case' lines to check for other
                    // permissions this app might request
            }

            EventArgs eventArgs = new EventArgs();

            OnPermissionsResult(this, eventArgs);
        }

        public override void OnBackPressed()
        {
            base.OnBackPressed();

            OverridePendingTransition(Resource.Animation.anim_slide_in_bottom, Resource.Animation.anim_slide_out_bottom);
        }
    }
}