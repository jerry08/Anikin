using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AndroidX.RecyclerView.Widget;
using AnimeDl;
using AnimeDl.Models;
using AniStream.Adapters;
using AniStream.Utils;
using Google.Android.Material.BottomSheet;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace AniStream.Fragments
{
    internal class SelectorDialogFragment : BottomSheetDialogFragment
    {
        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);
        private readonly Anime _anime;
        private readonly Episode _episode;

        private View _view;

        SelectorDialogFragment(Anime anime, Episode episode)
        {
            _episode = episode;
            _anime = anime;
        }

        public static SelectorDialogFragment NewInstance(
            Anime anime, Episode episode)
        {
            return new SelectorDialogFragment(anime, episode);
        }

        public override View OnCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState)
        {
            _view = inflater.Inflate(Resource.Layout.bottom_sheet_selector, container, false);
            var autoLayout = _view.FindViewById<LinearLayout>(Resource.Id.selectorAutoListContainer);
            var layout = _view.FindViewById<LinearLayout>(Resource.Id.selectorListContainer);
            
            var selectorMakeDefault = _view.FindViewById<CheckBox>(Resource.Id.selectorMakeDefault);
            var serversRecyclerView = _view.FindViewById<RecyclerView>(Resource.Id.selectorRecyclerView);
            var selectorProgressBar = _view.FindViewById<ProgressBar>(Resource.Id.selectorProgressBar);

            selectorMakeDefault.Visibility = ViewStates.Gone;

            /*_client.OnVideoServersLoaded += (s, e) =>
            {
                if (e.VideoServers.Count > 0)
                    _client.GetVideos(e.VideoServers[0]);
            };

            int totalServersLoaded = 0;
            _client.OnVideosLoaded += (s, e) =>
            {
                totalServersLoaded++;
                
                if (totalServersLoaded >= _client.VideoServers.Count)
                {
                    selectorProgressBar.Visibility = ViewStates.Gone;
                }
                else
                {
                    var servers = e.VideoServers.Select(x => x.Name).ToArray();

                    var adapter = new ExtractorAdapter(_client, e.VideoServers);

                    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                    serversRecyclerView.HasFixedSize = true;
                    serversRecyclerView.SetItemViewCacheSize(20);
                    serversRecyclerView.SetAdapter(adapter);
                }
            };*/

            //_client.OnVideoServersLoaded += (s, e) =>
            //{
            //    var servers = e.VideoServers.Select(x => x.Name).ToArray();
            //
            //    var adapter = new ExtractorAdapter(Activity, _client, e.VideoServers);
            //
            //    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
            //    serversRecyclerView.HasFixedSize = true;
            //    serversRecyclerView.SetItemViewCacheSize(20);
            //    serversRecyclerView.SetAdapter(adapter);
            //};
            //
            //int totalServersLoaded = 0;
            //_client.OnVideosLoaded += (s, e) =>
            //{
            //    totalServersLoaded++;
            //
            //    if (totalServersLoaded >= _client.VideoServers.Count)
            //    {
            //        selectorProgressBar.Visibility = ViewStates.Gone;
            //    }
            //};

            _client.OnVideoServersLoaded += (s, e) =>
            {
                if (e.VideoServers.Count > 0)
                    _client.GetVideos(e.VideoServers[0]);
            };

            int totalServersLoaded = 0;
            _client.OnVideosLoaded += (s, e) =>
            {
                totalServersLoaded++;

                if (totalServersLoaded >= _client.VideoServers.Count)
                {
                    selectorProgressBar.Visibility = ViewStates.Gone;
                    return;
                }
                else
                {
                    _client.GetVideos(_client.VideoServers[totalServersLoaded]);
                }

                if (e.Videos.Count <= 0)
                {
                    return;
                }

                if (serversRecyclerView.GetAdapter() is ExtractorAdapter adapter)
                {
                    adapter.Containers.Add(new ServerWithVideos(e.VideoServer, e.Videos));
                }
                else
                {
                    var containers = new List<ServerWithVideos>
                    {
                        new ServerWithVideos(e.VideoServer, e.Videos)
                    };

                    adapter = new ExtractorAdapter(Activity, _anime, _episode, containers);

                    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                    serversRecyclerView.HasFixedSize = true;
                    serversRecyclerView.SetItemViewCacheSize(20);
                    serversRecyclerView.SetAdapter(adapter);
                }

                adapter.NotifyDataSetChanged();
            };

            _client.GetVideoServers(_episode);

            return _view;
        }

        public override void OnViewCreated(View view, Bundle savedInstanceState)
        {
            base.OnViewCreated(view, savedInstanceState);
        }

        public override void OnDismiss(IDialogInterface dialog)
        {
            _client.CancelGetVideoServers();
            _client.CancelGetVideos();
            base.OnDismiss(dialog);
        }
    }
}