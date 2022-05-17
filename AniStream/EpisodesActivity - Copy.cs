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

namespace AniStream
{
    [Activity(Label = "EpisodesActivity", Theme = "@style/AppTheme", ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize)]
    public class EpisodesActivity : AppCompatActivity
    {
        public AnimeScraper AnimeScraper;
        public event EventHandler<EventArgs> OnPermissionsResult;

        ListView EpisodesListView;
        RecyclerView episodesRecyclerView;
        List<Episode> Episodes = new List<Episode>();
        List<View> Views = new List<View>();
        Anime anime;
        NestedScrollView nestedScrollView;
        ConstraintLayout linearLayout;
        LinearLayout linearLayout2;
        
        TextView type;
        TextView genres;
        TextView plotsummary;
        TextView released;
        TextView status;
        TextView othernames;
        
        ImageView imageofanime;
        EditText editText;
        RelativeLayout relativeLayout1;
        ConstraintLayout constraintLayout1;
        ConstraintLayout constraintLayout2;
        AppBarLayout bar;
        ProgressBar ProgressBar;
        TextView notbutton;
        TextView bookmarkbtn;
        bool isBooked;
        bool IsAscending;

        BookmarkManager BookmarkManager;

        protected override void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            
            SetContentView(Resource.Layout.newepisodelayout);

            BookmarkManager = new BookmarkManager();

            string animeString = Intent.GetStringExtra("anime");
            if (!string.IsNullOrEmpty(animeString))
            {
                anime = JsonConvert.DeserializeObject<Anime>(animeString);
            }

            var toolbar = FindViewById<AndroidX.AppCompat.Widget.Toolbar>(Resource.Id.actiontool);
            nestedScrollView = FindViewById<NestedScrollView>(Resource.Id.nestedscrollview);
            //linearLayout = FindViewById<LinearLayout>(Resource.Id.linear);
            linearLayout = FindViewById<ConstraintLayout>(Resource.Id.linear);
            linearLayout2 = FindViewById<LinearLayout>(Resource.Id.LinearLayout2);
            notbutton = FindViewById<TextView>(Resource.Id.notbutton);
            
            type = FindViewById<TextView>(Resource.Id.type);
            genres = FindViewById<TextView>(Resource.Id.genres);
            plotsummary = FindViewById<TextView>(Resource.Id.summary);
            released = FindViewById<TextView>(Resource.Id.released);
            status = FindViewById<TextView>(Resource.Id.status);
            othernames = FindViewById<TextView>(Resource.Id.othernames);
            
            imageofanime = FindViewById<ImageView>(Resource.Id.animeimage);
            SetSupportActionBar(toolbar);
            SupportActionBar.SetDisplayShowHomeEnabled(true);
            SupportActionBar.SetDisplayHomeAsUpEnabled(true);
            SupportActionBar.Title = anime.Title;
            editText = FindViewById<EditText>(Resource.Id.episodeno);
            episodesRecyclerView = FindViewById<RecyclerView>(Resource.Id.episodesRecyclerView);
            EpisodesListView = FindViewById<ListView>(Resource.Id.EpisodesListView);
            bookmarkbtn = FindViewById<TextView>(Resource.Id.bookmark);

            ProgressBar = FindViewById<ProgressBar>(Resource.Id.loading2);
            relativeLayout1 = FindViewById<RelativeLayout>(Resource.Id.rel);
            constraintLayout1 = FindViewById<ConstraintLayout>(Resource.Id.linear1);
            constraintLayout2 = FindViewById<ConstraintLayout>(Resource.Id.linear);
            bar = FindViewById<AppBarLayout>(Resource.Id.action);

            if (!string.IsNullOrEmpty(anime.Image))
            {
                Picasso.Get().Load(anime.Image).Into(imageofanime);
            }

            EpisodesListView.Visibility = ViewStates.Gone;
            episodesRecyclerView.Visibility = ViewStates.Visible;

            editText.TextChanged += (s, e) =>
            {
                if (episodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
                {
                    if (string.IsNullOrEmpty(e.Text.ToString()))
                    {
                        episodeRecyclerAdapter.Episodes = Episodes.ToList();
                        episodeRecyclerAdapter.NotifyDataSetChanged();

                        return;
                    }

                    string ep = e.Text.ToString();

                    List<Episode> episodes = Episodes
                        .Where(x => x.EpisodeNumber == Convert.ToInt32(ep))
                        .ToList();

                    episodeRecyclerAdapter.Episodes = episodes.ToList();
                    episodeRecyclerAdapter.NotifyDataSetChanged();
                }
                else
                {
                    if (string.IsNullOrEmpty(e.Text.ToString()))
                    {
                        linearLayout2.RemoveAllViews();
                        for (int i = 0; i < Views.Count; i++)
                        {
                            linearLayout2.AddView(Views[i]);
                        }

                        return;
                    }

                    string ep = e.Text.ToString();

                    List<Episode> episodes = Episodes
                        .Where(x => x.EpisodeNumber == Convert.ToInt32(ep))
                        .ToList();

                    SortEpList(episodes);
                }
            };

            editText.Click += (s, e) =>
            {
                //int scrollTo = ((View)editText.Parent).Top + editText.Top;
                //nestedScrollView.SmoothScrollTo(0, constraintLayout1.Top);
            };

            linearLayout.Visibility = ViewStates.Gone;
            relativeLayout1.Visibility = ViewStates.Gone;
            episodesRecyclerView.Visibility = ViewStates.Gone;
            plotsummary.Visibility = ViewStates.Gone;
            imageofanime.Visibility = ViewStates.Gone;
            bar.Visibility = ViewStates.Gone;
            ProgressBar.Visibility = ViewStates.Visible;

            ISharedPreferences bookmarksPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
            IsAscending = bookmarksPref.GetBoolean("isAscending", false);

            isBooked = BookmarkManager.IsBookmarked(anime);

            if (isBooked)
            {
                bookmarkbtn.SetBackgroundResource(Resource.Drawable.bookmarked);
            }
            else
            {
                bookmarkbtn.SetBackgroundResource(Resource.Drawable.round_background);
            }

            bookmarkbtn.Click += (s, e) =>
            {
                if (isBooked)
                {
                    BookmarkManager.RemoveBookmark(anime);
                }
                else
                {
                    BookmarkManager.SaveBookmark(anime);
                }

                isBooked = BookmarkManager.IsBookmarked(anime);

                if (isBooked)
                {
                    bookmarkbtn.SetBackgroundResource(Resource.Drawable.bookmarked);
                }
                else
                {
                    bookmarkbtn.SetBackgroundResource(Resource.Drawable.round_background);
                }
            };

            AnimeScraper = new AnimeScraper();
            AnimeScraper.OnEpisodesLoaded += (s, e) =>
            {
                Episodes = e.Episodes;

                if (!IsAscending)
                {
                    Episodes = Episodes.OrderByDescending(x => x.EpisodeNumber).ToList();
                }
                else
                {
                    Episodes = Episodes.OrderBy(x => x.EpisodeNumber).ToList();
                }

                ProgressBar.Visibility = ViewStates.Gone;
                linearLayout.Visibility = ViewStates.Visible;
                relativeLayout1.Visibility = ViewStates.Visible;
                episodesRecyclerView.Visibility = ViewStates.Visible;
                plotsummary.Visibility = ViewStates.Visible;
                imageofanime.Visibility = ViewStates.Visible;
                bar.Visibility = ViewStates.Visible;

                notbutton.Text = BookmarkManager.GetLastWatchedEp(this, anime).ToString() + "/"
                    + Episodes.Count.ToString();

                type.Text = e.Anime.Type;
                genres.Text = "Genre: " + e.Anime.Genre;
                plotsummary.Text = e.Anime.Summary;
                released.Text = e.Anime.Released;
                status.Text = e.Anime.Status;
                othernames.Text = e.Anime.OtherNames;

                TextViewExtensions.MakeTextViewResizable(plotsummary, 3, "See More", true);

                type.SetText(TextViewExtensions.MakeSectionOfTextBold(type.Text, "Type:"), TextView.BufferType.Spannable);
                genres.SetText(TextViewExtensions.MakeSectionOfTextBold(genres.Text, "Genre:"), TextView.BufferType.Spannable);
                released.SetText(TextViewExtensions.MakeSectionOfTextBold(released.Text, "Released:"), TextView.BufferType.Spannable);
                status.SetText(TextViewExtensions.MakeSectionOfTextBold(status.Text, "Status:"), TextView.BufferType.Spannable);
                othernames.SetText(TextViewExtensions.MakeSectionOfTextBold(othernames.Text, "Other name:"), TextView.BufferType.Spannable);
                plotsummary.SetText(TextViewExtensions.MakeSectionOfTextBold(plotsummary.Text, "Plot Summary:"), TextView.BufferType.Spannable);

                editText.SetFilters(new IInputFilter[] { new InputFilterMinMax(1, Episodes.Count) });

                editText.Hint = $"Filter Episode no. between 1 and {Episodes.Count}";

                for (int i = 0; i < Episodes.Count; i++)
                {
                    //TextView textView = new TextView(this);
                    View view = LayoutInflater.Inflate(Resource.Layout.adapterforepisode, null);

                    LinearLayout layout = view.FindViewById<LinearLayout>(Resource.Id.linearlayouta);
                    TextView button = view.FindViewById<TextView>(Resource.Id.notbutton);
                    ImageButton download = view.FindViewById<ImageButton>(Resource.Id.downloadchoice);

                    button.Tag = i;
                    button.Text = $"Episode {Episodes[i].EpisodeNumber}";
                    download.Click += (s, e) =>
                    {
                        Downloader downloader = new Downloader(this, anime, Episodes[(int)button.Tag]);
                        downloader.Download();
                    };
                    layout.Click += (s, e) =>
                    {
                        //string link = Episodes[position].EpisodeLink;

                        Intent intent = new Intent(this, typeof(VideoActivity));
                        //intent.PutExtra("link", link);
                        intent.PutExtra("episode", JsonConvert.SerializeObject(Episodes[(int)button.Tag]));
                        intent.PutExtra("anime", JsonConvert.SerializeObject(anime));
                        intent.SetFlags(ActivityFlags.NewTask);
                        ApplicationContext.StartActivity(intent);
                    };

                    Views.Add(view);
                    linearLayout2.AddView(view);
                }
            };

            AnimeScraper.GetEpisodes(anime);

            //EpisodesListView.Adapter = new EpisodeAdapter(Episodes, this);
        }

        private void SortEpList(List<Episode> episodes)
        {
            linearLayout2.RemoveAllViews();
            for (int i = 0; i < episodes.Count; i++)
            {
                //TextView textView = new TextView(this);
                View view = LayoutInflater.Inflate(Resource.Layout.adapterforepisode, null);

                LinearLayout layout = view.FindViewById<LinearLayout>(Resource.Id.linearlayouta);
                TextView button = view.FindViewById<TextView>(Resource.Id.notbutton);
                ImageButton download = view.FindViewById<ImageButton>(Resource.Id.downloadchoice);

                button.Tag = i;
                button.Text = episodes[i].EpisodeName;
                download.Click += (s, e) =>
                {
                    Downloader downloader = new Downloader(this, anime, episodes[(int)button.Tag]);
                    downloader.Download();
                };
                layout.Click += (s, e) =>
                {
                    //string link = Episodes[position].EpisodeLink;

                    Intent intent = new Intent(this, typeof(VideoActivity));
                    //intent.PutExtra("link", link);
                    intent.PutExtra("episode", JsonConvert.SerializeObject(episodes[(int)button.Tag]));
                    intent.PutExtra("anime", JsonConvert.SerializeObject(anime));
                    intent.SetFlags(ActivityFlags.NewTask);
                    this.ApplicationContext.StartActivity(intent);
                };

                linearLayout2.AddView(view);
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

        public override bool OnCreateOptionsMenu(IMenu menu)
        {
            MenuInflater.Inflate(Resource.Menu.drawer_epsiodes, menu);
            IMenuItem sortAscending = menu.FindItem(Resource.Id.sort_ascending);
            IMenuItem sortDescending = menu.FindItem(Resource.Id.sort_descending);

            if (IsAscending)
            {
                sortAscending.SetChecked(true);
            }
            else
            {
                sortDescending.SetChecked(false);
            }

            return true;
        }

        public override bool OnOptionsItemSelected(IMenuItem item)
        {
            if (item.ItemId == Resource.Id.sort_ascending)
            {
                IsAscending = true;
                item.SetChecked(true);

                Episodes = Episodes.OrderBy(x => x.EpisodeNumber).ToList();

                if (episodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
                {
                    episodeRecyclerAdapter.Episodes = Episodes.ToList();
                    episodeRecyclerAdapter.NotifyDataSetChanged();
                }
                else
                {
                    SortEpList(Episodes);
                }

                ISharedPreferences isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
                isAscendingPref.Edit().PutBoolean("isAscending", IsAscending).Commit();

                InvalidateOptionsMenu();

                return true;
            }
            else if (item.ItemId == Resource.Id.sort_descending)
            {
                IsAscending = false;
                item.SetChecked(true);

                Episodes = Episodes.OrderByDescending(x => x.EpisodeNumber).ToList();

                if (episodesRecyclerView.GetAdapter() is EpisodeRecyclerAdapter episodeRecyclerAdapter)
                {
                    episodeRecyclerAdapter.Episodes = Episodes.ToList();
                    episodeRecyclerAdapter.NotifyDataSetChanged();
                }
                else
                {
                    SortEpList(Episodes);
                }

                ISharedPreferences isAscendingPref = this.GetSharedPreferences("isAscendingPref", FileCreationMode.Private);
                isAscendingPref.Edit().PutBoolean("isAscending", IsAscending).Commit();

                InvalidateOptionsMenu();

                return true;
            }

            this.OnBackPressed();

            return base.OnOptionsItemSelected(item);
        }

        public override void OnBackPressed()
        {
            base.OnBackPressed();

            OverridePendingTransition(Resource.Animation.anim_slide_in_bottom, Resource.Animation.anim_slide_out_bottom);
        }
    }
}