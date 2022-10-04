using System;
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
    public class VideoAdapter : RecyclerView.Adapter
    {
        private readonly Anime _anime;
        private readonly Episode _episode;

        public Activity Activity { get; set; }

        public List<Video> Videos { get; set; }

        public VideoAdapter(Activity activity, Anime anime, Episode episode,
            List<Video> videos)
        {
            Activity = activity;
            _anime = anime;
            _episode = episode;
            Videos = videos;
        }

        class UrlViewHolder : RecyclerView.ViewHolder
        {
            public TextView urlQuality;
            public TextView urlNote;
            public TextView urlSize;
            public ImageButton urlDownload;

            public UrlViewHolder(View view) : base (view)
            {
                urlQuality = view.FindViewById<TextView>(Resource.Id.urlQuality);
                urlNote = view.FindViewById<TextView>(Resource.Id.urlNote);
                urlSize = view.FindViewById<TextView>(Resource.Id.urlSize);
                urlDownload = view.FindViewById<ImageButton>(Resource.Id.urlDownload);
            }
        }

        public override int ItemCount => Videos.Count;

        public override long GetItemId(int position)
        {
            return position;
        }

        public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
        {
            var urlViewHolder = holder as UrlViewHolder;

            var video = Videos[urlViewHolder.BindingAdapterPosition];

            if (!string.IsNullOrEmpty(video.Resolution))
            {
                urlViewHolder.urlQuality.Text = video.Resolution;
            }
            else
            {
                urlViewHolder.urlQuality.Text = "Default Quality";
            }

            urlViewHolder.urlDownload.Click += (s, e) =>
            {
                //var downloader = new Downloader(EpisodesActivity, _anime, Episodes[holder2.BindingAdapterPosition]);
                //downloader.Download();
            };

            urlViewHolder.ItemView.Click += (s, e) =>
            {
                var intent = new Intent(Activity, typeof(VideoActivity));

                intent.PutExtra("anime", JsonConvert.SerializeObject(_anime));
                intent.PutExtra("episode", JsonConvert.SerializeObject(_episode));
                intent.PutExtra("video", JsonConvert.SerializeObject(video));
                intent.SetFlags(ActivityFlags.NewTask);

                Activity.ApplicationContext.StartActivity(intent);
            };

            urlViewHolder.ItemView.LongClick += (s, e) =>
            {
                var url = video.VideoUrl.Replace(" ", "%20");
                var videoUri = Android.Net.Uri.Parse(url);

                var intent = new Intent(Intent.ActionView);
                intent.SetDataAndType(videoUri, "video/*");
                intent.SetFlags(ActivityFlags.NewTask);

                WeebUtils.CopyToClipboard(Activity, url);

                var i = Intent.CreateChooser(intent, "Open Video in :");
                i.SetFlags(ActivityFlags.NewTask);

                Activity.ApplicationContext.StartActivity(i);
            };
        }

        public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
        {
            View itemView = LayoutInflater.From(parent.Context)
                .Inflate(Resource.Layout.item_url, parent, false);

            return new UrlViewHolder(itemView);
        }
    }
}