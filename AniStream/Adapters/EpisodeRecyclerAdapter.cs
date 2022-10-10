using System.Collections.Generic;
using Android.Views;
using Android.Widget;
using AndroidX.RecyclerView.Widget;
using Square.Picasso;
using Newtonsoft.Json;
using AnimeDl;
using AniStream.Utils;
using AniStream.Fragments;
using AnimeDl.Models;
using AndroidX.CardView.Widget;

namespace AniStream.Adapters
{
    public class EpisodeRecyclerAdapter : RecyclerView.Adapter
    {
        private readonly Anime _anime;

        private readonly EpisodesActivity _episodesActivity;

        public List<Episode> Episodes { get; set; }

        public EpisodeRecyclerAdapter(List<Episode> episodes,
            EpisodesActivity activity,
            Anime anime)
        {
            _anime = anime;
            Episodes = episodes;
            _episodesActivity = activity;
        }

        class EpisodeViewHolder : RecyclerView.ViewHolder
        {
            public CardView cardView;
            public TextView episodeNumber;

            public EpisodeViewHolder(View view) : base (view)
            {
                cardView = view.FindViewById<CardView>(Resource.Id.cardView);
                episodeNumber = view.FindViewById<TextView>(Resource.Id.episodeNumber);
            }
        }

        public override int ItemCount => Episodes.Count;

        public override long GetItemId(int position)
        {
            return position;
        }

        public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
        {
            var episodeViewHolder = holder as EpisodeViewHolder;

            var ep = $"EP {Episodes[position].Number}";

            episodeViewHolder.episodeNumber.Text = ep;

            if (episodeViewHolder.cardView.HasOnClickListeners)
                return;

            episodeViewHolder.cardView.Click += (s, e) =>
            {
                var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

                var selector = SelectorDialogFragment.NewInstance(_anime, episode);
                selector.Show(_episodesActivity.SupportFragmentManager, "dialog");
            };
        }

        public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
        {
            View itemView = LayoutInflater.From(parent.Context)
                .Inflate(Resource.Layout.recycler_episode_item, parent, false);

            return new EpisodeViewHolder(itemView);
        }
    }
}