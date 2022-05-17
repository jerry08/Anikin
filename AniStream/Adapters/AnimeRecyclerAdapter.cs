using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Views.Animations;
using Android.Widget;
using AndroidX.CardView.Widget;
using AndroidX.RecyclerView.Widget;
using Java.Lang;
using Newtonsoft.Json;
using Square.Picasso;
using AniStream.Fragments;
using AniStream.ViewHolders;
using AnimeDl;

namespace AniStream.Adapters
{
    public class AnimeRecyclerAdapter : RecyclerView.Adapter
    {
        //Context Context { get; set; }
        Activity Activity { get; set; }
        public List<Anime> Animes { get; set; }
        int lastPosition = -1;
        AnimeFragment AnimeFragment;

        public AnimeRecyclerAdapter(Activity activity, List<Anime> animes, AnimeFragment animeFragment = null)
        {
            Animes = animes;
            Activity = activity;
            AnimeFragment = animeFragment;
        }

        public class MyViewHolder : RecyclerView.ViewHolder
        {
            public CardView cardView;
            public TextView title, episodeno;
            public Uri animeuri, imageuri;
            public ImageView imageofanime;
            public ProgressBar loadMoreProgressBar;

            public MyViewHolder(View view) : base(view)
            {
                title = view.FindViewById<TextView>(Resource.Id.animename);
                episodeno = view.FindViewById<TextView>(Resource.Id.episodeno);
                imageofanime = view.FindViewById<ImageView>(Resource.Id.img);
                cardView = view.FindViewById<CardView>(Resource.Id.cardview);
                loadMoreProgressBar = view.FindViewById<ProgressBar>(Resource.Id.loadMoreProgressBar);

                episodeno.Visibility = ViewStates.Gone;
            }
        }

        public override int ItemCount => Animes.Count;

        public override long GetItemId(int position)
        {
            return position;
        }

        public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
        {
            MyViewHolder holder2 = holder as MyViewHolder;

            //Anime anime = Animes[position];
            Anime anime = Animes[holder2.BindingAdapterPosition];

            if (anime != null && anime.Id == -1 && AnimeFragment != null)
            {
                holder2.loadMoreProgressBar.Visibility = ViewStates.Visible;
                //holder2.episodeno.Visibility = ViewStates.Visible;
                //holder2.episodeno.Text = "Loading More...";
                holder2.title.Text = "Loading More...";
                //holder2.cardView.SetBackgroundColor(Color.Transparent);
                holder2.cardView.CardElevation = 0f;

                //Animation animation2 = AnimationUtils.LoadAnimation(Context,
                //    (position > lastPosition) ? Resource.Animation.up_from_bottom
                //        : Resource.Animation.down_from_top);

                //Animation animation2 = AnimationUtils.LoadAnimation(Context, 
                //    Resource.Animation.up_from_bottom);
                //
                //holder2.ItemView.StartAnimation(animation2);
                //lastPosition = position;

                AnimeFragment.Search();

                return;
            }

            if (holder2.loadMoreProgressBar.Visibility == ViewStates.Visible)
            {
                holder2.loadMoreProgressBar.Visibility = ViewStates.Gone;
                holder2.cardView.CardElevation = 4;
            }

            //holder2.animeuri = Uri.Parse(mSiteLink.get(position));

            holder2.title.Text = Animes[position].Title;
            //holder2.episodeno.Text = mEpisodeList.get(position);

            if (!holder2.cardView.HasOnClickListeners)
            {
                holder2.cardView.Click += (s, e) =>
                {
                    //var test = Animes[position].Name; 
                    //var anime2 = anime.Name;
                    //var test3 = holder2.title.Text;

                    Anime anime2 = Animes[holder2.BindingAdapterPosition];
                    //Anime anime3 = Animes[position];

                    Intent intent = new Intent(Activity, typeof(EpisodesActivity));
                    intent.PutExtra("anime", JsonConvert.SerializeObject(anime2));
                    intent.SetFlags(ActivityFlags.NewTask);
                    Activity.StartActivity(intent);

                    Activity.OverridePendingTransition(Resource.Animation.anime_slide_in_top, Resource.Animation.anime_slide_out_top);
                };
            }

            //Animation animation = AnimationUtils.LoadAnimation(Context,
            //    (position > lastPosition) ? Resource.Animation.up_from_bottom
            //        : Resource.Animation.down_from_top);
            //holder2.ItemView.StartAnimation(animation);

            Animation animation = AnimationUtils.LoadAnimation(Activity,
                Resource.Animation.up_from_bottom);
            holder2.ItemView.StartAnimation(animation);

            lastPosition = position;

            if (!string.IsNullOrEmpty(Animes[position].Image))
            {
                Picasso.Get().Load(Animes[position].Image)
                    .Fit().CenterCrop().Into(holder2.imageofanime);
            }
        }

        public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
        {
            View itemView = LayoutInflater.From(parent.Context)
                .Inflate(Resource.Layout.row_data, parent, false);

            return new MyViewHolder(itemView);
        }

        public override void OnViewDetachedFromWindow(Object holder)
        {
            base.OnViewDetachedFromWindow(holder);
            (holder as MyViewHolder).ItemView.ClearAnimation();
        }
    }
}