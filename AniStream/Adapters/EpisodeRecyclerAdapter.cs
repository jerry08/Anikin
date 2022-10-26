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
using AniStream.Settings;
using Android.Content;

namespace AniStream.Adapters;

public class EpisodeRecyclerAdapter : RecyclerView.Adapter
{
    private readonly PlayerSettings _playerSettings = new();

    private readonly Anime _anime;

    private readonly EpisodesActivity _episodesActivity;

    public List<Episode> Episodes { get; set; }

    public EpisodeRecyclerAdapter(List<Episode> episodes,
        EpisodesActivity activity,
        Anime anime)
    {
        _anime = anime;
        _episodesActivity = activity;
        Episodes = episodes;

        _playerSettings.Load();
    }

    class EpisodeViewHolder : RecyclerView.ViewHolder
    {
        public CardView cardView = default!;
        public TextView episodeNumber = default!;

        public EpisodeViewHolder(View view) : base (view)
        {
            cardView = view.FindViewById<CardView>(Resource.Id.cardView)!;
            episodeNumber = view.FindViewById<TextView>(Resource.Id.episodeNumber)!;
        }
    }

    public override int ItemCount => Episodes.Count;

    public override long GetItemId(int position)=> position;

    public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
    {
        var episodeViewHolder = (holder as EpisodeViewHolder)!;

        var ep = $"EP {Episodes[position].Number}";

        episodeViewHolder.episodeNumber.Text = ep;

        if (episodeViewHolder.cardView.HasOnClickListeners)
            return;

        episodeViewHolder.cardView.LongClick += (s, e) =>
        {
            var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

            var selector = SelectorDialogFragment.NewInstance(_anime, episode);
            selector.Show(_episodesActivity.SupportFragmentManager, "dialog");
        };

        episodeViewHolder.cardView.Click += (s, e) =>
        {
            var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

            if (_playerSettings.SelectServerBeforePlaying)
            {
                var selector = SelectorDialogFragment.NewInstance(_anime, episode);
                selector.Show(_episodesActivity.SupportFragmentManager, "dialog");
            }
            else
            {
                var intent = new Intent(_episodesActivity, typeof(VideoActivity));

                intent.PutExtra("anime", JsonConvert.SerializeObject(_anime));
                intent.PutExtra("episode", JsonConvert.SerializeObject(episode));
                intent.SetFlags(ActivityFlags.NewTask);

                _episodesActivity.ApplicationContext!.StartActivity(intent);
            }
        };
    }

    public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
    {
        var itemView = LayoutInflater.From(parent.Context)!
            .Inflate(Resource.Layout.recycler_episode_item, parent, false)!;

        return new EpisodeViewHolder(itemView);
    }
}