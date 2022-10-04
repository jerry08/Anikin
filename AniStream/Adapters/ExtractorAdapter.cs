﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using Newtonsoft.Json;
using Square.Picasso;
using AniStream.ViewHolders;
using AnimeDl;
using AniStream.Utils;
using AndroidX.RecyclerView.Widget;
using AniStream.Fragments;
using AnimeDl.Models;

namespace AniStream.Adapters
{
    public class ServerWithVideos
    {
        public VideoServer VideoServer { get; set; }

        public List<Video> Videos { get; set; }

        public ServerWithVideos(VideoServer videoServer,
            List<Video> videos)
        {
            VideoServer = videoServer;
            Videos = videos;
        }
    }

    public class ExtractorAdapter : RecyclerView.Adapter
    {
        private readonly Anime _anime;
        private readonly Episode _episode;

        public Activity Activity { get; set; }

        public List<ServerWithVideos> Containers { get; set; }

        public ExtractorAdapter(Activity activity, Anime anime, Episode episode,
            List<ServerWithVideos> containers)
        {
            Activity = activity;
            _anime = anime;
            _episode = episode;
            Containers = containers;
        }

        class StreamViewHolder : RecyclerView.ViewHolder
        {
            public TextView streamName;
            public RecyclerView streamRecyclerView;

            public StreamViewHolder(View view) : base (view)
            {
                streamName = view.FindViewById<TextView>(Resource.Id.streamName);
                streamRecyclerView = view.FindViewById<RecyclerView>(Resource.Id.streamRecyclerView);
            }
        }

        public override int ItemCount => Containers.Count;

        public override long GetItemId(int position)
        {
            return position;
        }

        public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
        {
            var streamViewHolder = holder as StreamViewHolder;

            var server = Containers[streamViewHolder.BindingAdapterPosition].VideoServer;
            var videos = Containers[streamViewHolder.BindingAdapterPosition].Videos;

            streamViewHolder.streamName.Text = server.Name;

            if (!(streamViewHolder.streamRecyclerView.GetAdapter()
                is VideoAdapter))
            {
                var adapter = new VideoAdapter(Activity, _anime, _episode, videos);

                streamViewHolder.streamRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                streamViewHolder.streamRecyclerView.HasFixedSize = true;
                streamViewHolder.streamRecyclerView.SetItemViewCacheSize(20);
                streamViewHolder.streamRecyclerView.SetAdapter(adapter);
            }

            //if (!(streamViewHolder.streamRecyclerView.GetAdapter()
            //    is VideoAdapter))
            //{
            //    _client.OnVideosLoaded += (s, e) =>
            //    {
            //
            //    };
            //
            //    _client.GetVideos(server);
            //}
        }

        public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
        {
            View itemView = LayoutInflater.From(parent.Context)
                .Inflate(Resource.Layout.item_stream, parent, false);

            return new StreamViewHolder(itemView);
        }
    }
}