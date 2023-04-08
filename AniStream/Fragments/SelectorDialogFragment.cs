using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Android.Content;
using Android.OS;
using Android.Views;
using Android.Widget;
using AndroidX.Fragment.App;
using AndroidX.RecyclerView.Widget;
using AniStream.Adapters;
using AniStream.Utils;
using Google.Android.Material.BottomSheet;
using Httpz.Extensions;
using Juro.Models.Anime;
using Juro.Models.Videos;
using Juro.Providers.Anime;
using Xamarin.Android.Net;
using Orientation = Android.Content.Res.Orientation;

namespace AniStream.Fragments;

internal class SelectorDialogFragment : BottomSheetDialogFragment
{
    //public static readonly Dictionary<Episode, List<ServerWithVideos>> Cache = new();
    public static readonly Dictionary<string, List<ServerWithVideos>> Cache = new();

    private readonly IAnimeProvider _client = WeebUtils.AnimeClient;
    private readonly AnimeInfo _anime;
    private readonly Episode _episode;

    private readonly VideoActivity? _videoActivity;

    private View _view = default!;

    public CancellationTokenSource CancellationTokenSource { get; set; } = new();

    SelectorDialogFragment(
        AnimeInfo anime,
        Episode episode,
        VideoActivity? videoActivity = null)
    {
        _videoActivity = videoActivity;
        _episode = episode;
        _anime = anime;
    }

    public static SelectorDialogFragment NewInstance(
        AnimeInfo anime,
        Episode episode,
        VideoActivity? videoActivity = null)
        => new(anime, episode, videoActivity);

    public override void OnStart()
    {
        base.OnStart();

        if (this.Resources.Configuration!.Orientation != Orientation.Portrait)
        {
            var behavior = BottomSheetBehavior.From((RequireView().Parent as View)!);
            behavior.State = BottomSheetBehavior.StateExpanded;
        }
    }

    public override View OnCreateView(LayoutInflater inflater, ViewGroup? container, Bundle? savedInstanceState)
    {
        _view = inflater.Inflate(Resource.Layout.bottom_sheet_selector, container, false)!;
        var autoLayout = _view.FindViewById<LinearLayout>(Resource.Id.selectorAutoListContainer);
        var layout = _view.FindViewById<LinearLayout>(Resource.Id.selectorListContainer);

        var selectorMakeDefault = _view.FindViewById<CheckBox>(Resource.Id.selectorMakeDefault)!;
        var serversRecyclerView = _view.FindViewById<RecyclerView>(Resource.Id.selectorRecyclerView)!;
        var selectorProgressBar = _view.FindViewById<ProgressBar>(Resource.Id.selectorProgressBar)!;

        selectorMakeDefault.Visibility = ViewStates.Gone;

        Load(serversRecyclerView, selectorProgressBar);

        return _view;
    }

    private async void Load(RecyclerView serversRecyclerView, ProgressBar selectorProgressBar)
    {
        try
        {
            var activity = (_videoActivity ?? Activity)!;

            var cache = Cache.GetValueOrDefault(_episode.Link);
            if (cache is null)
            {
                cache = new();

                var videoServers = await _client.GetVideoServersAsync(
                    _episode.Id,
                    CancellationTokenSource.Token
                );

                var serverWithVideos = videoServers.ConvertAll(x => new ServerWithVideos(x, new()));

                Cache.Add(_episode.Link, serverWithVideos);

                for (var i = 0; i < videoServers.Count; i++)
                {
                    var videos = await _client.GetVideosAsync(
                        videoServers[i],
                        CancellationTokenSource.Token
                    );

                    if (videos.Count == 0)
                    {
                        Cache[_episode.Link][i] = new(videoServers[i], videos)
                        {
                            IsLoaded = true
                        };

                        continue;
                    }

                    //try
                    //{
                    //    // Try get sizes
                    //    var http = new HttpClient(new AndroidMessageHandler());
                    //
                    //    foreach (var video in videos)
                    //    {
                    //        if (video.Format == VideoType.Container)
                    //        {
                    //            video.Size = await Task.Run(async
                    //                () => await http.GetFileSizeAsync(
                    //                    video.VideoUrl,
                    //                    video.Headers,
                    //                    CancellationTokenSource.Token
                    //                )
                    //            );
                    //        }
                    //    }
                    //}
                    //catch
                    //{
                    //    // Ignore
                    //}

                    if (serversRecyclerView.GetAdapter() is ExtractorAdapter adapter)
                    {
                        adapter.Containers.Add(new(videoServers[i], videos)
                        {
                            IsLoaded = true
                        });

                        cache = adapter.Containers;
                    }
                    else
                    {
                        var containers = new List<ServerWithVideos>
                        {
                            new(videoServers[i], videos)
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

                    //Cache.Remove(_episode.Link);
                    //Cache.Add(_episode.Link, cache);

                    Cache[_episode.Link][i] = new(videoServers[i], videos)
                    {
                        IsLoaded = true
                    };

                    adapter.NotifyDataSetChanged();
                }
            }
            else
            {
                var notLoadedServers = cache.Where(x => !x.IsLoaded)
                    .Select(x => x.VideoServer).ToList();
                if (notLoadedServers.Count == 0)
                {
                    cache = cache.Where(x => x.IsLoaded && x.Videos.Count > 0).ToList();

                    var adapter = new ExtractorAdapter(activity, _anime, _episode, cache);

                    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                    serversRecyclerView.HasFixedSize = true;
                    serversRecyclerView.SetItemViewCacheSize(20);
                    serversRecyclerView.SetAdapter(adapter);
                }
                else
                {
                    var adapter = new ExtractorAdapter(activity, _anime, _episode,
                        cache.Where(x => x.IsLoaded && x.Videos.Count > 0).ToList());

                    serversRecyclerView.SetLayoutManager(new LinearLayoutManager(Activity));
                    serversRecyclerView.HasFixedSize = true;
                    serversRecyclerView.SetItemViewCacheSize(20);
                    serversRecyclerView.SetAdapter(adapter);

                    for (var i = 0; i < notLoadedServers.Count; i++)
                    {
                        var videos = await _client.GetVideosAsync(
                            notLoadedServers[i],
                            CancellationTokenSource.Token
                        );

                        if (videos.Count == 0)
                            continue;

                        var notLoadedServer = notLoadedServers[i];
                        var item = Cache[_episode.Link].Find(x => x.VideoServer == notLoadedServer)!;

                        if (videos.Count == 0)
                        {
                            item.IsLoaded = true;
                            continue;
                        }

                        adapter = (ExtractorAdapter)serversRecyclerView.GetAdapter()!;

                        adapter.Containers.Add(new(notLoadedServers[i], videos)
                        {
                            IsLoaded = true
                        });

                        cache = adapter.Containers;

                        //Cache.Remove(_episode.Link);
                        //Cache.Add(_episode.Link, cache);

                        //Cache[_episode.Link] = cache;

                        item.IsLoaded = true;
                        item.VideoServer = notLoadedServers[i];
                        item.Videos = videos;

                        //Cache[_episode.Link][notLoadedServer] = new(e.VideoServer, e.Videos)
                        //{
                        //    IsLoaded = true
                        //};

                        adapter.NotifyDataSetChanged();
                    }
                }
            }
        }
        catch
        {
            // Operation cancelled
        }
        finally
        {
            selectorProgressBar.Visibility = ViewStates.Gone;
        }
    }

    public override void Show(FragmentManager manager, string? tag)
    {
        var ft = manager.BeginTransaction();
        ft.Add(this, tag);
        ft.CommitAllowingStateLoss();
        //base.Show(manager, tag);
    }

    public override void OnDismiss(IDialogInterface dialog)
    {
        CancellationTokenSource.Cancel();
        base.OnDismiss(dialog);
    }
}