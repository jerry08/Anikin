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
using Square.Picasso;
using AniStream.ViewHolders;
using AnimeDl;

namespace AniStream.Adapters
{
    public class EpisodeAdapter : BaseAdapter<Episode>
    {
        EpisodesActivity EpisodesActivity { get; set; }
        public List<Episode> Episodes { get; set; }

        public EpisodeAdapter(List<Episode> episodes, EpisodesActivity activity)
        {
            this.Episodes = episodes;

            EpisodesActivity = activity;
        }

        public override Episode this[int position]
        {
            get
            {
                return Episodes[position];
            }
        }

        public override int Count
        {
            get
            {
                return Episodes.Count;
            }
        }

        public override long GetItemId(int position)
        {
            return position;
        }

        public override View GetView(int position, View view, ViewGroup parent)
        {
            if (view == null)
            {
                view = LayoutInflater.From(parent.Context).Inflate(Resource.Layout.adapterforepisode, parent, false);

                var episodeName = view.FindViewById<TextView>(Resource.Id.notbutton);
                var downloadBtn = view.FindViewById<Button>(Resource.Id.downloadchoice);

                view.Tag = new ViewHolder()
                {
                    Name = episodeName,
                    DownloadBtn = downloadBtn
                };
            }

            var holder = (ViewHolder)view.Tag;

            holder.Name.Text = Episodes[position].EpisodeName;

            return view;
        }
    }
}