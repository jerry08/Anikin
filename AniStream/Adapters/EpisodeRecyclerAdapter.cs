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

namespace AniStream.Adapters
{
    public class EpisodeRecyclerAdapter : RecyclerView.Adapter
    {
        EpisodesActivity EpisodesActivity { get; set; }
        public List<Episode> Episodes { get; set; }
        Anime Anime;

        public EpisodeRecyclerAdapter(List<Episode> episodes, EpisodesActivity activity, Anime anime)
        {
            Episodes = episodes;
            Anime = anime;
            EpisodesActivity = activity;
        }

        class MyViewHolder : RecyclerView.ViewHolder
        {
            public TextView button;
            //public Button download;
            public ImageButton download;
            public LinearLayout layout;

            public MyViewHolder(View view) : base (view)
            {
                layout = view.FindViewById<LinearLayout>(Resource.Id.linearlayouta);
                button = view.FindViewById<TextView>(Resource.Id.notbutton);
                download = view.FindViewById<ImageButton>(Resource.Id.downloadchoice);

                //download.Visibility = ViewStates.Gone;
            }
        }

        public override int ItemCount => Episodes.Count;

        public override long GetItemId(int position)
        {
            return position;
        }

        public override void OnBindViewHolder(RecyclerView.ViewHolder holder, int position)
        {
            var holder2 = (holder as MyViewHolder);

            holder2.button.Text = Episodes[position].EpisodeName;
            holder2.download.Click += (s, e) =>
            {
                Downloader downloader = new Downloader(EpisodesActivity, Anime, Episodes[position]);
                downloader.Download();
            };
            holder2.layout.Click += (s, e) =>
            {
                Intent intent = new Intent(EpisodesActivity, typeof(VideoActivity));
                //intent.PutExtra("link", link);
                intent.PutExtra("episode", JsonConvert.SerializeObject(Episodes[position]));
                intent.PutExtra("anime", JsonConvert.SerializeObject(Anime));
                intent.SetFlags(ActivityFlags.NewTask);
                EpisodesActivity.ApplicationContext.StartActivity(intent);
            };
        }

        public override RecyclerView.ViewHolder OnCreateViewHolder(ViewGroup parent, int viewType)
        {
            View itemView = LayoutInflater.From(parent.Context)
                .Inflate(Resource.Layout.adapterforepisode, parent, false);

            return new MyViewHolder(itemView);
        }
    }
}