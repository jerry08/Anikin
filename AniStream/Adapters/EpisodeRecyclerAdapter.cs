using System.Collections.Generic;
using System.Text.Json;
using Android.Content;
using Android.Views;
using Android.Widget;
using AndroidX.CardView.Widget;
using AndroidX.RecyclerView.Widget;
using AniStream.Fragments;
using AniStream.Services;
using Juro.Models.Anime;

namespace AniStream.Adapters;

public class EpisodeRecyclerAdapter : RecyclerView.Adapter
{
    private readonly PlayerSettings _playerSettings;

    private readonly IAnimeInfo _anime;

    private readonly EpisodesActivity _episodesActivity;

    public List<Episode> Episodes { get; set; }

    public EpisodeRecyclerAdapter(
        List<Episode> episodes,
        EpisodesActivity activity,
        IAnimeInfo anime,
        PlayerSettings playerSettings)
    {
        _anime = anime;
        _episodesActivity = activity;
        Episodes = episodes;

        _playerSettings = playerSettings;
    }

    class EpisodeViewHolder : RecyclerView.ViewHolder
    {
        public CardView CardView = default!;
        public TextView EpisodeNumber = default!;
        public ProgressBar WatchedProgress = default!;

        public EpisodeViewHolder(View view) : base(view)
        {
            CardView = view.FindViewById<CardView>(Resource.Id.cardView)!;
            EpisodeNumber = view.FindViewById<TextView>(Resource.Id.episodeNumber)!;
            WatchedProgress = view.FindViewById<ProgressBar>(Resource.Id.watchedProgress)!;
        }
    }

    public override int ItemCount => Episodes.Count;

    public override long GetItemId(int position) => position;

    public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
    {
        var episodeViewHolder = (holder as EpisodeViewHolder)!;

        var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

        var ep = $"EP {episode.Number}";
        episodeViewHolder.EpisodeNumber.Text = ep;

        if (_playerSettings.WatchedEpisodes.ContainsKey(episode.Id))
        {
            var watchedEpisode = _playerSettings.WatchedEpisodes[episode.Id];
            if (watchedEpisode is not null)
                episodeViewHolder.WatchedProgress.Progress = (int)watchedEpisode.WatchedPercentage;
        }

        if (episodeViewHolder.CardView.HasOnClickListeners)
            return;

        episodeViewHolder.CardView.LongClick += (s, e) =>
        {
            //Declare episode variable after click to get correct episode after fast scroll
            var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

            var selector = SelectorDialogFragment.NewInstance(_anime, episode);
            selector.Show(_episodesActivity.SupportFragmentManager, "dialog");
        };

        episodeViewHolder.CardView.Click += (s, e) =>
        {
            //Declare episode variable after click to get correct episode after fast scroll
            var episode = Episodes[episodeViewHolder.BindingAdapterPosition];

            if (_playerSettings.SelectServerBeforePlaying)
            {
                var selector = SelectorDialogFragment.NewInstance(_anime, episode);
                selector.Show(_episodesActivity.SupportFragmentManager, "dialog");
            }
            else
            {
                var intent = new Intent(_episodesActivity, typeof(VideoActivity));

                intent.PutExtra("anime", JsonSerializer.Serialize(_anime));
                intent.PutExtra("episode", JsonSerializer.Serialize(episode));
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