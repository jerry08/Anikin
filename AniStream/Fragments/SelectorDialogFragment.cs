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
        //public static readonly Dictionary<Episode, List<ServerWithVideos>> Cache = new();
        public static readonly Dictionary<string, List<ServerWithVideos>> Cache = new();

        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);
        private readonly Anime _anime;
        private readonly Episode _episode;

        private readonly VideoActivity _videoActivity;

        private View _view;

        SelectorDialogFragment(Anime anime, Episode episode,
            VideoActivity? videoActivity = null)
        {
            _videoActivity = videoActivity;
            _episode = episode;
            _anime = anime;
        }

        public static SelectorDialogFragment NewInstance(
            Anime anime, Episode episode, VideoActivity? videoActivity = null)
        {
            return new SelectorDialogFragment(anime, episode, videoActivity);
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

            var activity = _videoActivity ?? Activity;

            var cache = Cache.GetValueOrDefault(_episode.Link);
            if (cache is null)
            {
                cache = new();

                int totalServersLoaded = 0;

                _client.OnVideoServersLoaded += (s, e) =>
                {
                    var serverWithVideos = e.VideoServers
                        .Select(x => new ServerWithVideos(x, new())).ToList();

                    Cache.Add(_episode.Link, serverWithVideos);

                    if (e.VideoServers.Count > 0)
                        _client.GetVideos(e.VideoServers[0]);
                };

                _client.OnVideosLoaded += (s, e) =>
                {
                    totalServersLoaded++;

                    if (totalServersLoaded >= _client.VideoServers.Count)
                    {
                        selectorProgressBar.Visibility = ViewStates.Gone;
                    }
                    else
                    {
                        _client.GetVideos(_client.VideoServers[totalServersLoaded]);
                    }

                    if (e.Videos.Count <= 0)
                        return;

                    if (serversRecyclerView.GetAdapter() is ExtractorAdapter adapter)
                    {
                        adapter.Containers.Add(new(e.VideoServer, e.Videos)
                        {
                            IsLoaded = true
                        });

                        cache = adapter.Containers;
                    }
                    else
                    {
                        var containers = new List<ServerWithVideos>
                        {
                            new(e.VideoServer, e.Videos)
                            {
                                IsLoaded = true
                            }
                        };

                        cache.AddRange(containers);

                        adapter = new ExtractorAdapter(activity, _anime, _episode, containers);

                        serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                        serversRecyclerView.HasFixedSize = true;
                        serversRecyclerView.SetItemViewCacheSize(20);
                        serversRecyclerView.SetAdapter(adapter);
                    }

                    Cache.Remove(_episode.Link);
                    Cache.Add(_episode.Link, cache);

                    adapter.NotifyDataSetChanged();
                };

                _client.GetVideoServers(_episode);
            }
            else
            {
                var notLoadedServers = cache.Where(x => !x.IsLoaded)
                    .Select(x => x.VideoServer).ToList();
                if (notLoadedServers.Count <= 0)
                {
                    var adapter = new ExtractorAdapter(activity, _anime, _episode, cache);

                    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                    serversRecyclerView.HasFixedSize = true;
                    serversRecyclerView.SetItemViewCacheSize(20);
                    serversRecyclerView.SetAdapter(adapter);

                    selectorProgressBar.Visibility = ViewStates.Gone;
                }
                else
                {
                    int totalServersLoaded = 0;

                    _client.OnVideosLoaded += (s, e) =>
                    {
                        totalServersLoaded++;

                        if (totalServersLoaded >= notLoadedServers.Count)
                        {
                            selectorProgressBar.Visibility = ViewStates.Gone;
                            return;
                        }
                        else
                        {
                            _client.GetVideos(_client.VideoServers[totalServersLoaded]);
                        }

                        if (e.Videos.Count <= 0)
                            return;

                        if (serversRecyclerView.GetAdapter() is ExtractorAdapter adapter)
                        {
                            adapter.Containers.Add(new(e.VideoServer, e.Videos)
                            {
                                IsLoaded = true
                            });

                            cache = adapter.Containers;
                        }
                        else
                        {
                            var containers = new List<ServerWithVideos>
                            {
                                new(e.VideoServer, e.Videos)
                                {
                                    IsLoaded = true
                                }
                            };

                            cache.AddRange(containers);

                            adapter = new ExtractorAdapter(activity, _anime, _episode, containers);

                            serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                            serversRecyclerView.HasFixedSize = true;
                            serversRecyclerView.SetItemViewCacheSize(20);
                            serversRecyclerView.SetAdapter(adapter);
                        }

                        Cache.Remove(_episode.Link);
                        Cache.Add(_episode.Link, cache);

                        adapter.NotifyDataSetChanged();
                    };

                    _client.GetVideos(notLoadedServers[0]);
                }
            }

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