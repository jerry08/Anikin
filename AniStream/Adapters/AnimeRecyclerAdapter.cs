using System.Collections.Generic;
using System.Text.Json;
using Android.App;
using Android.Content;
using Android.Net;
using Android.Views;
using Android.Views.Animations;
using Android.Widget;
using AndroidX.CardView.Widget;
using AndroidX.RecyclerView.Widget;
using AniStream.Fragments;
using Java.Lang;
using Juro.Models.Anime;
using Square.Picasso;

namespace AniStream.Adapters;

public class AnimeRecyclerAdapter : RecyclerView.Adapter
{
    Activity Activity { get; set; }
    public List<IAnimeInfo> Animes { get; set; }

    private int lastPosition = -1;

    private AnimeFragment? AnimeFragment;

    public AnimeRecyclerAdapter(
        Activity activity,
        List<IAnimeInfo> animes,
        AnimeFragment? animeFragment = null)
    {
        Animes = animes;
        Activity = activity;
        AnimeFragment = animeFragment;
    }

    public class MyViewHolder : RecyclerView.ViewHolder
    {
        public CardView cardView = default!;
        public TextView title, episodeno = default!;
        public Uri animeuri = default!, imageuri = default!;
        public ImageView imageofanime = default!;
        public ProgressBar loadMoreProgressBar = default!;

        public MyViewHolder(View view) : base(view)
        {
            title = view.FindViewById<TextView>(Resource.Id.animename)!;
            episodeno = view.FindViewById<TextView>(Resource.Id.episodeno)!;
            imageofanime = view.FindViewById<ImageView>(Resource.Id.img)!;
            cardView = view.FindViewById<CardView>(Resource.Id.cardview)!;
            loadMoreProgressBar = view.FindViewById<ProgressBar>(Resource.Id.loadMoreProgressBar)!;

            episodeno.Visibility = ViewStates.Gone;
        }
    }

    public override int ItemCount => Animes.Count;

    public override long GetItemId(int position) => position;

    public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
    {
        var animeViewholder = (holder as MyViewHolder)!;

        var anime = Animes[animeViewholder.BindingAdapterPosition];

        if (anime?.Id == "-1" && AnimeFragment != null)
        {
            animeViewholder.loadMoreProgressBar.Visibility = ViewStates.Visible;
            //animeViewholder.episodeno.Visibility = ViewStates.Visible;
            //animeViewholder.episodeno.Text = "Loading More...";
            animeViewholder.title.Text = "Loading More...";
            //animeViewholder.cardView.SetBackgroundColor(Color.Transparent);
            animeViewholder.cardView.CardElevation = 0f;

            //Animation animation2 = AnimationUtils.LoadAnimation(Context,
            //    (position > lastPosition) ? Resource.Animation.up_from_bottom
            //        : Resource.Animation.down_from_top);

            //Animation animation2 = AnimationUtils.LoadAnimation(Context, 
            //    Resource.Animation.up_from_bottom);
            //
            //animeViewholder.ItemView.StartAnimation(animation2);
            //lastPosition = position;

            AnimeFragment.Search();

            return;
        }

        if (animeViewholder.loadMoreProgressBar.Visibility == ViewStates.Visible)
        {
            animeViewholder.loadMoreProgressBar.Visibility = ViewStates.Gone;
            animeViewholder.cardView.CardElevation = 4;
        }

        animeViewholder.title.Text = Animes[position].Title;

        if (!animeViewholder.cardView.HasOnClickListeners)
        {
            animeViewholder.cardView.Click += (s, e) =>
            {
                var anime2 = Animes[animeViewholder.BindingAdapterPosition];

                var intent = new Intent(Activity, typeof(EpisodesActivity));
                intent.PutExtra("anime", JsonSerializer.Serialize(anime2));
                intent.SetFlags(ActivityFlags.NewTask);

                Activity.StartActivity(intent);

                Activity.OverridePendingTransition(Resource.Animation.anime_slide_in_top, Resource.Animation.anime_slide_out_top);
            };
        }

        //Animation animation = AnimationUtils.LoadAnimation(Context,
        //    (position > lastPosition) ? Resource.Animation.up_from_bottom
        //        : Resource.Animation.down_from_top);
        //animeViewholder.ItemView.StartAnimation(animation);

        var animation = AnimationUtils.LoadAnimation(Activity, Resource.Animation.up_from_bottom);
        animeViewholder.ItemView.StartAnimation(animation);

        lastPosition = position;

        if (!string.IsNullOrEmpty(Animes[position].Image))
        {
            Picasso.Get().Load(anime?.Image).Fit().CenterCrop()
                .Into(animeViewholder.imageofanime);
        }
    }

    public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
    {
        var itemView = LayoutInflater.From(parent.Context)!
            .Inflate(Resource.Layout.row_data, parent, false)!;

        return new MyViewHolder(itemView);
    }

    public override void OnViewDetachedFromWindow(Object holder)
    {
        base.OnViewDetachedFromWindow(holder);
        (holder as MyViewHolder)!.ItemView.ClearAnimation();
    }
}