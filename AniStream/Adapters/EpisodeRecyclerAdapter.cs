using System.Collections.Generic;
using Android.Views;
using Android.Widget;
using AndroidX.RecyclerView.Widget;
using Square.Picasso;
using Newtonsoft.Json;
using AnimeDl;
using AniStream.Utils;
using AniStream.Fragments;

namespace AniStream.Adapters
{
    public class EpisodeRecyclerAdapter : RecyclerView.Adapter
    {
        private readonly AnimeClient _client;
        private readonly Anime _anime;

        EpisodesActivity EpisodesActivity { get; set; }

        public List<Episode> Episodes { get; set; }

        public EpisodeRecyclerAdapter(AnimeClient client,
            List<Episode> episodes, EpisodesActivity activity,
            Anime anime)
        {
            _client = client;
            _anime = anime;
            Episodes = episodes;
            EpisodesActivity = activity;
        }

        class MyViewHolder : RecyclerView.ViewHolder
        {
            public TextView button;
            public ImageButton download;
            public LinearLayout layout;

            public MyViewHolder(View view) : base (view)
            {
                layout = view.FindViewById<LinearLayout>(Resource.Id.linearlayouta);
                button = view.FindViewById<TextView>(Resource.Id.notbutton);
                download = view.FindViewById<ImageButton>(Resource.Id.downloadchoice);
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

            holder2.button.Text = Episodes[position].Name;
            holder2.download.Click += (s, e) =>
            {
                var downloader = new Downloader(EpisodesActivity, _anime, Episodes[holder2.BindingAdapterPosition]);
                downloader.Download();
            };

            holder2.layout.Click += (s, e) =>
            {
                var episode = Episodes[holder2.BindingAdapterPosition];

                var fragment = SelectorDialogFragment.NewInstance(_client, _anime, episode);
                fragment.Show(EpisodesActivity.SupportFragmentManager, "tag1");
                
                return;

                /*var loadingDialog = WeebUtils.SetProgressDialog(EpisodesActivity, "Loading Servers...", false);

                _client.OnVideoServersLoaded += (s2, e2) =>
                {
                    loadingDialog.Dismiss();

                    var servers = e2.VideoServers.Select(x => x.Name).ToArray();

                    var builder = new AlertDialog.Builder(EpisodesActivity,
                        AlertDialog.ThemeDeviceDefaultLight);
                    builder.SetTitle("Select Server");
                    builder.SetItems(servers, (s3, e3) =>
                    {
                        var intent = new Intent(EpisodesActivity, typeof(VideoActivity));
                        //intent.PutExtra("link", link);
                        intent.PutExtra("anime", JsonConvert.SerializeObject(_anime));
                        intent.PutExtra("episode", JsonConvert.SerializeObject(episode));
                        intent.PutExtra("videoServer", JsonConvert.SerializeObject(e2.VideoServers[e3.Which]));
                        intent.SetFlags(ActivityFlags.NewTask);
                        EpisodesActivity.ApplicationContext.StartActivity(intent);
                    });
                    builder.Show();
                };

                _client.GetVideoServers(episode);*/
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