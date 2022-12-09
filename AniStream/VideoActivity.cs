using System;
using System.Collections.Generic;
using System.Linq;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using Com.Google.Android.Exoplayer2;
using Com.Google.Android.Exoplayer2.Extractor;
using Com.Google.Android.Exoplayer2.Source;
using Com.Google.Android.Exoplayer2.Source.Hls;
using Com.Google.Android.Exoplayer2.Trackselection;
using Com.Google.Android.Exoplayer2.UI;
using Com.Google.Android.Exoplayer2.Upstream;
using Com.Google.Android.Exoplayer2.Util;
using Newtonsoft.Json;
using AniStream.Utils;
using AnimeDl;
using AniStream.BroadcastReceivers;
using AndroidX.AppCompat.App;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using AnimeDl.Models;
using AniStream.Fragments;
using AnimeDl.Utils.Extensions;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using static Com.Google.Android.Exoplayer2.IPlayer;
using Square.OkHttp3;
using System.Threading.Tasks;
using Com.Google.Android.Exoplayer2.Video;
using Com.Google.Android.Exoplayer2.Ext.Okhttp;
using Android.Graphics.Drawables;
using Bumptech.Glide;
using AndroidX.CardView.Widget;
using AniStream.Settings;
using Google.Android.Material.Card;
using AndroidX.Core.View;
using Android.Util;
using AnimeDl.Anilist;
using AnimeDl.Scrapers;
using Handler = Android.OS.Handler;
using AnimeDl.Aniskip;
using AniStream.Utils.Extensions;
using Configuration = Android.Content.Res.Configuration;
using AniStream.Models;
using AnimeDl.Scrapers.Events;
using AniStream.Adapters;

namespace AniStream;

[Activity(Label = "VideoActivity", Theme = "@style/VideoPlayerTheme",
    ResizeableActivity = true, LaunchMode = LaunchMode.SingleTask, SupportsPictureInPicture = true,
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.SmallestScreenSize | ConfigChanges.ScreenLayout | ConfigChanges.Keyboard | ConfigChanges.KeyboardHidden)]
public class VideoActivity : AppCompatActivity, IPlayer.IListener,
    INetworkStateReceiverListener, ITrackNameProvider
{
    private readonly AnimeClient _client = new(WeebUtils.AnimeSite);

    private readonly PlayerSettings _playerSettings = new();
    
    private Anime Anime = default!;
    private Episode Episode = default!;
    private Video Video = default!;

    //private NetworkStateReceiver NetworkStateReceiver = default!;

    private IExoPlayer exoPlayer = default!;
    private StyledPlayerView playerView = default!;
    //private PlayerView playerView = default!;
    DefaultTrackSelector trackSelector = default!;

    private ProgressBar progressBar = default!;
    private ImageButton exoplay = default!;
    private ImageButton exoQuality = default!;
    //private int currentVideoIndex;
    //private LinearLayout controls = default!;
    private TextView animeTitle = default!;
    private TextView episodeTitle = default!;
    //private TextView errorText = default!;
    private TextView VideoInfo = default!;
    private TextView VideoName = default!;
    private TextView ServerInfo = default!;

    private ImageButton PrevButton = default!;
    private ImageButton NextButton = default!;

    private MaterialCardView ExoSkip = default!;
    private ImageButton ExoSkipOpEd = default!;
    private MaterialCardView SkipTimeButton = default!;
    private TextView SkipTimeText = default!;
    private TextView TimeStampText = default!;

    private Handler Handler { get; set; } = new Handler(Looper.MainLooper!);

    private bool IsPipEnabled { get; set; } = false;
    private Rational AspectRatio { get; set; } = new(16, 9);
    private bool PlayAfterEnteringPipMode { get; set; } = false;

    private OrientationEventListener? OrientationListener { get; set; }

    private SelectorDialogFragment? selector;

    private bool IsBuffering { get; set; } = true;

    private bool IsTimeStampsLoaded { get; set; }

    private bool CanSaveProgress { get; set; }

    protected async override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        SetContentView(Resource.Layout.activity_exoplayer);

        WindowCompat.SetDecorFitsSystemWindows(Window!, false);
        this.HideSystemBars();

        //Enable unhandled exceptions for testing
        AndroidEnvironment.UnhandledExceptionRaiser += (s, e) =>
        {
        
        };
        
        AppDomain.CurrentDomain.UnhandledException += (s, e) =>
        {
        
        };
        
        TaskScheduler.UnobservedTaskException += (s, e) =>
        {
        
        };

        await _playerSettings.LoadAsync();

        if (_playerSettings.AlwaysInLandscapeMode && Build.VERSION.SdkInt >= BuildVersionCodes.Gingerbread)
            RequestedOrientation = ScreenOrientation.SensorLandscape;

        var animeString = Intent!.GetStringExtra("anime");
        if (!string.IsNullOrEmpty(animeString))
            Anime = JsonConvert.DeserializeObject<Anime>(animeString)!;

        var episodeString = Intent.GetStringExtra("episode");
        if (!string.IsNullOrEmpty(episodeString))
            Episode = JsonConvert.DeserializeObject<Episode>(episodeString)!;
        
        var bookmarkManager = new BookmarkManager("recently_watched");

        var isBooked = await bookmarkManager.IsBookmarked(Anime);
        if (isBooked)
            bookmarkManager.RemoveBookmark(Anime);
        
        bookmarkManager.SaveBookmark(Anime, true);

        //NetworkStateReceiver = new NetworkStateReceiver();
        //NetworkStateReceiver.AddListener(this);
        //RegisterReceiver(NetworkStateReceiver, new IntentFilter(Android.Net.ConnectivityManager.ConnectivityAction));

        animeTitle = FindViewById<TextView>(Resource.Id.exo_anime_title)!;
        episodeTitle = FindViewById<TextView>(Resource.Id.exo_ep_sel)!;

        playerView = FindViewById<StyledPlayerView>(Resource.Id.player_view)!;
        exoplay = FindViewById<ImageButton>(Resource.Id.exo_play)!;
        exoQuality = FindViewById<ImageButton>(Resource.Id.exo_quality)!;
        //progressBar = FindViewById<ProgressBar>(Resource.Id.buffer)!;
        progressBar = FindViewById<ProgressBar>(Resource.Id.exo_init_buffer)!;
        
        //errorText = FindViewById<TextView>(Resource.Id.errorText)!;
        VideoInfo = FindViewById<TextView>(Resource.Id.exo_video_info)!;
        VideoName = FindViewById<TextView>(Resource.Id.exo_video_name)!;
        ServerInfo = FindViewById<TextView>(Resource.Id.exo_server_info)!;

        VideoName.Selected = true;

        ExoSkip = FindViewById<MaterialCardView>(Resource.Id.exo_skip)!;

        PrevButton = FindViewById<ImageButton>(Resource.Id.exo_prev_ep)!;
        NextButton = FindViewById<ImageButton>(Resource.Id.exo_next_ep)!;

        PrevButton.Click += (s, e) =>
        {
            PlayPreviousEpisode();
        };

        NextButton.Click += (s, e) =>
        {
            PlayNextEpisode();
        };

        var settingsButton = FindViewById<ImageButton>(Resource.Id.exo_settings)!;
        var sourceButton = FindViewById<ImageButton>(Resource.Id.exo_source)!;
        var subButton = FindViewById<ImageButton>(Resource.Id.exo_sub)!;
        var downloadButton = FindViewById<ImageButton>(Resource.Id.exo_download)!;
        var exoPip = FindViewById<ImageButton>(Resource.Id.exo_pip)!;
        ExoSkipOpEd = FindViewById<ImageButton>(Resource.Id.exo_skip_op_ed)!;
        SkipTimeButton = FindViewById<MaterialCardView>(Resource.Id.exo_skip_timestamp)!;
        SkipTimeText = FindViewById<TextView>(Resource.Id.exo_skip_timestamp_text)!;
        TimeStampText = FindViewById<TextView>(Resource.Id.exo_time_stamp_text)!;
        var exoSpeed = FindViewById<ImageButton>(Resource.Id.exo_playback_speed)!;
        var exoScreen = FindViewById<ImageButton>(Resource.Id.exo_screen)!;
        
        var backButton = FindViewById<ImageButton>(Resource.Id.exo_back)!;
        var lockButton = FindViewById<ImageButton>(Resource.Id.exo_lock)!;

        //TODO: Implement these
        settingsButton.Visibility = ViewStates.Gone;
        subButton.Visibility = ViewStates.Gone;
        lockButton.Visibility = ViewStates.Gone;

        SetNextAndPrev();

        //if (Android.Provider.Settings.System.GetInt(ContentResolver, Android.Provider.Settings.System.AccelerometerRotation, 0) != 1)
        //{
        //
        //}

        if (Build.VERSION.SdkInt >= BuildVersionCodes.N)
        {
            IsPipEnabled = PackageManager!.HasSystemFeature(PackageManager.FeaturePictureInPicture);
            
            if (IsPipEnabled)
            {
                exoPip.Visibility = ViewStates.Visible;
                exoPip.Click += (s, e) =>
                {
                    PlayAfterEnteringPipMode = true;
                    EnterPipMode();
                };
            }
            else
            {
                exoPip.Visibility = ViewStates.Gone;
            }
        }

        SkipTimeButton.Click += (s, e) =>
        {
            if (CurrentTimeStamp is not null)
                exoPlayer.SeekTo((long)(CurrentTimeStamp.Interval.EndTime * 1000));
        };

        exoScreen.Click += (s, e) =>
        {
            if (_playerSettings.ResizeMode < PlayerResizeMode.Stretch)
                _playerSettings.ResizeMode++;
            else
                _playerSettings.ResizeMode = PlayerResizeMode.Original;

            switch (_playerSettings.ResizeMode)
            {
                case PlayerResizeMode.Original:
                    playerView.ResizeMode = AspectRatioFrameLayout.ResizeModeFit;
                    this.ToastString("Original");
                    break;
                case PlayerResizeMode.Zoom:
                    playerView.ResizeMode = AspectRatioFrameLayout.ResizeModeZoom;
                    this.ToastString("Zoom");
                    break;
                case PlayerResizeMode.Stretch:
                    playerView.ResizeMode = AspectRatioFrameLayout.ResizeModeFill;
                    this.ToastString("Stretch");
                    break;
                default:
                    this.ToastString("Original");
                    break;
            }
        };

        exoSpeed.Click += (s, e) =>
        {
            var speeds = _playerSettings.GetSpeeds();
            var speedsName = speeds.Select(x => $"{x}x").ToArray();

            var speedDialog = new AlertDialog.Builder(this, Resource.Style.DialogTheme);
            speedDialog.SetSingleChoiceItems(speedsName,
                _playerSettings.DefaultSpeedIndex, (dialog, e) =>
            {
                exoPlayer.PlaybackParameters = new PlaybackParameters(speeds[e.Which]);
                (dialog as AlertDialog)?.Dismiss();
            });

            speedDialog.Show();
        };

        sourceButton.Click += (s, e) =>
        {
            selector = SelectorDialogFragment.NewInstance(Anime, Episode, this);
            selector.Show(SupportFragmentManager, "dialog");
        };

        backButton.Click += (s, e) =>
        {
            this.OnBackPressed();
        };

        ExoSkip.Click += (s, e) =>
        {
            exoPlayer.SeekTo(exoPlayer.CurrentPosition + 85000);
        };

        var fastForwardCont = FindViewById<CardView>(Resource.Id.exo_fast_forward_button_cont)!;
        var fastRewindCont = FindViewById<CardView>(Resource.Id.exo_fast_rewind_button_cont)!;
        var fastForwardButton = FindViewById<ImageButton>(Resource.Id.exo_fast_forward_button)!;
        var rewindButton = FindViewById<ImageButton>(Resource.Id.exo_fast_rewind_button)!;

        fastForwardCont.Visibility = ViewStates.Visible;
        fastRewindCont.Visibility = ViewStates.Visible;

        fastForwardButton.Click += (s, e) =>
        {
            exoPlayer.SeekTo(exoPlayer.CurrentPosition + _playerSettings.SeekTime);
        };

        rewindButton.Click += (s, e) =>
        {
            exoPlayer.SeekTo(exoPlayer.CurrentPosition - _playerSettings.SeekTime);
        };

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        //var ff = trackSelector.BuildUponParameters();
        //ff.SetMinVideoSize(720, 480).SetMaxVideoSize(1, 1);
        //
        //trackSelector.SetParameters(ff);

        playerView.ControllerShowTimeoutMs = 5000;

        SetupExoPlayer();

        if (_playerSettings.SelectServerBeforePlaying)
        {
            var videoString = Intent.GetStringExtra("video");
            if (!string.IsNullOrEmpty(videoString))
                Video = JsonConvert.DeserializeObject<Video>(videoString)!;

            PlayVideo(Video);
        }
        else
        {
            var progressBar = FindViewById<ProgressBar>(Resource.Id.exo_init_buffer)!;
            progressBar.Visibility = ViewStates.Visible;

            _client.OnVideosLoaded += OnVideosLoaded;
            _client.OnVideoServersLoaded += OnVideoServersLoaded;

            _client.GetVideoServers(Episode.Id);
        }
    }

    private void SetupExoPlayer()
    {
        var trackSelectionFactory = new AdaptiveTrackSelection.Factory();
        trackSelector = new DefaultTrackSelector(this, trackSelectionFactory);

        exoPlayer = new IExoPlayer.Builder(this)
            .SetTrackSelector(trackSelector)!
            .Build()!;

        playerView.Player = exoPlayer;
        exoPlayer.AddListener(this);

        //progressBar.Visibility = ViewStates.Visible;

        //Play Pause
        exoplay.Click += (s, e) =>
        {
            (exoplay.Drawable as IAnimatable)?.Start();

            if (exoPlayer.IsPlaying)
            {
                Glide.With(this).Load(Resource.Drawable.anim_play_to_pause)
                    .Into(exoplay);

                //Picasso.Get().Load(Resource.Drawable.anim_play_to_pause)
                //    //.Transform(new RoundedTransformation())
                //    .Fit().CenterCrop().Into(exoplay);

                exoPlayer.Pause();
            }
            else
            {
                Glide.With(this).Load(Resource.Drawable.anim_pause_to_play)
                    .Into(exoplay);

                //Picasso.Get().Load(Resource.Drawable.anim_pause_to_play)
                //     .Fit().CenterCrop().Into(exoplay);

                exoPlayer.Play();
            }
        };
    }

    /// <summary>
    /// Load next or previous episode
    /// </summary>
    /// <param name="episode">Next or previous episode</param>
    private async Task LoadEpisode(Episode? episode)
    {
        if (episode is null) return;

        var videoServers = await _client.GetVideoServersAsync(episode.Id);
        if (videoServers.Count == 0)
            return;

        var allVideos = (await Task.WhenAll(videoServers
            .Select(x => _client.GetVideosAsync(x)))).SelectMany(x => x).ToList();

        if (!SelectorDialogFragment.Cache.ContainsKey(episode.Link))
        {
            var serverWithVideos = videoServers
                .Select(x => new ServerWithVideos(x, allVideos)).ToList();

            SelectorDialogFragment.Cache.Add(episode.Link, serverWithVideos);
        }

        RunOnUiThread(() =>
        {
            SetNextAndPrev();
        });
    }

    private void SetNextAndPrev()
    {
        PrevButton.Visibility = ViewStates.Visible;
        NextButton.Visibility = ViewStates.Visible;

        var prevEpisode = GetPreviousEpisode();
        if (prevEpisode is not null
            && SelectorDialogFragment.Cache.ContainsKey(prevEpisode.Link))
        {
            PrevButton.Enabled = true;
            PrevButton.Alpha = 1f;
        }
        else
        {
            PrevButton.Enabled = false;
            PrevButton.Alpha = 0.5f;
        }

        var nextEpisode = GetNextEpisode();
        if (nextEpisode is not null
            && SelectorDialogFragment.Cache.ContainsKey(nextEpisode.Link))
        {
            NextButton.Enabled = true;
            NextButton.Alpha = 1f;
        }
        else
        {
            NextButton.Enabled = false;
            NextButton.Alpha = 0.5f;
        }
    }

    private void OnVideosLoaded(object? sender, VideoEventArgs e)
    {
        RunOnUiThread(() =>
        {
            if (e.Videos.Count > 0)
            {
                PlayVideo(e.Videos[0]);
                progressBar.Visibility = ViewStates.Gone;
            }
            else
            {
                progressBar.Visibility = ViewStates.Gone;
                this.ToastString("No videos found");
            }
        });
    }

    private void OnVideoServersLoaded(object? sender, VideoServerEventArgs e)
    {
        RunOnUiThread(() =>
        {
            var selectedVideoServer = e.VideoServers
                .Where(x => x.Name?.ToLower().Contains("streamsb") == true
                || x.Name?.ToLower().Contains("vidstream") == true).FirstOrDefault();

            if (e.VideoServers.Count > 0)
            {
                _client.GetVideos(selectedVideoServer ?? e.VideoServers[0]);
            }
            else
            {
                progressBar.Visibility = ViewStates.Gone;
                this.ToastString("No servers found");
            }
        });
    }

    public Episode? GetPreviousEpisode()
    {
        var currentEpisode = EpisodesActivity.Episodes.Where(x => x.Id == Episode.Id)
            .FirstOrDefault();
        if (currentEpisode is null)
            return null;

        var index = EpisodesActivity.Episodes.OrderBy(x => x.Number).ToList()
            .IndexOf(currentEpisode);

        var prevEpisode = EpisodesActivity.Episodes.OrderBy(x => x.Number)
            .ElementAtOrDefault(index - 1);

        return prevEpisode;
    }

    private async void PlayPreviousEpisode()
    {
        var prevEpisode = GetPreviousEpisode();
        if (prevEpisode is null)
            return;

        Episode = prevEpisode;

        exoPlayer.Pause();
        await UpdateProgress();

        Episode = prevEpisode;

        exoPlayer.Stop();
        exoPlayer.SeekTo(0);
        //exoPlayer.Release();

        _client.CancelGetVideoServers();
        _client.CancelGetVideos();
        VideoCache.Release();
        //SetupExoPlayer();

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        //progressBar.Visibility = ViewStates.Visible;

        _client.OnVideosLoaded -= OnVideosLoaded;
        _client.OnVideoServersLoaded -= OnVideoServersLoaded;

        _client.OnVideosLoaded += OnVideosLoaded;
        _client.OnVideoServersLoaded += OnVideoServersLoaded;

        _client.GetVideoServers(prevEpisode.Id);
        SetNextAndPrev();
    }

    public Episode? GetNextEpisode()
    {
        var currentEpisode = EpisodesActivity.Episodes.Where(x => x.Id == Episode.Id)
            .FirstOrDefault();
        if (currentEpisode is null)
            return null;

        var index = EpisodesActivity.Episodes.OrderBy(x => x.Number).ToList()
            .IndexOf(currentEpisode);

        var nextEpisode = EpisodesActivity.Episodes.OrderBy(x => x.Number)
            .ElementAtOrDefault(index + 1);

        return nextEpisode;
    }

    private async void PlayNextEpisode()
    {
        var nextEpisode = GetNextEpisode();
        if (nextEpisode is null)
            return;

        exoPlayer.Pause();
        await UpdateProgress();

        Episode = nextEpisode;

        exoPlayer.Stop();
        exoPlayer.SeekTo(0);
        //exoPlayer.Release();

        _client.CancelGetVideoServers();
        _client.CancelGetVideos();
        VideoCache.Release();
        //SetupExoPlayer();

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        //progressBar.Visibility = ViewStates.Visible;

        _client.OnVideosLoaded -= OnVideosLoaded;
        _client.OnVideoServersLoaded -= OnVideoServersLoaded;

        _client.OnVideosLoaded += OnVideosLoaded;
        _client.OnVideoServersLoaded += OnVideoServersLoaded;

        _client.GetVideoServers(Episode.Id);
        SetNextAndPrev();
    }

    protected override void OnDestroy()
    {
        base.OnDestroy();

        //NetworkStateReceiver.RemoveListener(this);
        //UnregisterReceiver(NetworkStateReceiver);
    }

    public override void OnBackPressed()
    {
        exoPlayer.Stop();
        exoPlayer.Release();
        _client.CancelGetVideoServers();
        _client.CancelGetVideos();
        VideoCache.Release();

        base.OnBackPressed();
    }

    //TODO: Implement when automatically going to next episode
    //private bool IsPreloading { get; set; }
    //public void UpdateProgress()
    //{
    //    if (exoPlayer.CurrentPosition / exoPlayer.Duration > 99)
    //    {
    //
    //    }
    //
    //    Handler.PostDelayed(() =>
    //    {
    //        UpdateProgress();
    //    }, 2500);
    //}

    private List<Stamp> SkippedTimeStamps { get; set; } = new();
    private Stamp? CurrentTimeStamp { get; set; }
    private async void LoadTimeStamps()
    {
        if (IsTimeStampsLoaded || WeebUtils.AnimeSite != AnimeSites.GogoAnime)
            return;

        var client = new AnilistClient();

        var searchResults = await client.SearchAsync("ANIME", search: Anime.Title);
        if (searchResults is null)
            return;

        var animes = searchResults?.Results.Where(x => x.IdMal is not null).ToList();
        if (animes is null || animes.Count <= 0)
            return;

        var media = await client.GetMediaDetailsAsync(animes[0]);
        if (media is null || media.IdMal is null)
            return;

        var timeStamps = await client.Aniskip.GetAsync(media.IdMal.Value, (int)Episode.Number, exoPlayer.Duration / 1000);
        if (timeStamps is null)
            return;

        SkippedTimeStamps.AddRange(timeStamps);

        var adGroups = new List<long>();
        for (int i = 0; i < timeStamps.Count; i++)
        {
            adGroups.Add((long)(timeStamps[i].Interval.StartTime * 1000));
            adGroups.Add((long)(timeStamps[i].Interval.EndTime * 1000));
        }

        var playedAdGroups = new List<bool>();
        for (int i = 0; i < timeStamps.Count; i++)
        {
            playedAdGroups.Add(false);
            playedAdGroups.Add(false);
        }

        playerView.SetExtraAdGroupMarkers(adGroups.ToArray(), playedAdGroups.ToArray());

        ExoSkipOpEd.Alpha = 1f;
        ExoSkipOpEd.Visibility = ViewStates.Visible;

        if (_playerSettings.TimeStampsEnabled && _playerSettings.ShowTimeStampButton)
            UpdateTimeStamp();
    }

    private void UpdateTimeStamp()
    {
        var playerCurrentTime = exoPlayer.CurrentPosition / 1000;
        CurrentTimeStamp = SkippedTimeStamps.Where(x => x.Interval.StartTime <= playerCurrentTime
            && playerCurrentTime < x.Interval.EndTime - 1).FirstOrDefault();

        if (CurrentTimeStamp is not null)
        {
            SkipTimeButton.Visibility = ViewStates.Visible;
            ExoSkip.Visibility = ViewStates.Gone;

            switch (CurrentTimeStamp.SkipType)
            {
                case SkipType.Opening:
                    SkipTimeText.Text = "Opening";
                    break;
                case SkipType.Ending:
                    SkipTimeText.Text = "Ending";
                    break;
                case SkipType.Recap:
                    SkipTimeText.Text = "Recap";
                    break;
                case SkipType.MixedOpening:
                    SkipTimeText.Text = "Mixed Opening";
                    break;
                case SkipType.MixedEnding:
                    SkipTimeText.Text = "Mixed Ending";
                    break;
            }
        }
        else
        {
            SkipTimeButton.Visibility = ViewStates.Gone;
            ExoSkip.Visibility= ViewStates.Visible;
        }

        Handler.PostDelayed(() =>
        {
            UpdateTimeStamp();
        }, 500);
    }

    // QUALITY SELECTOR
    private void ShowM3U8TrackSelector()
    {
        //var mappedTrackInfo = trackSelector.CurrentMappedTrackInfo;

        //var trackSelectionDialogBuilder = new TrackSelectionDialogBuilder(this,
        //    new Java.Lang.String("Available Qualities"), exoPlayer, C.TrackTypeVideo);

        var trackSelectionDialogBuilder = new TrackSelectionDialogBuilder(this,
            new Java.Lang.String("Available Qualities"), exoPlayer, C.TrackTypeVideo);

        trackSelectionDialogBuilder.SetTheme(Resource.Style.DialogTheme);
        //trackSelectionDialogBuilder.SetTrackNameProvider(this);

        var trackDialog = trackSelectionDialogBuilder.Build()!;
        //trackDialog.DismissEvent += (s, e) =>
        //{
        //    this.HideSystemUI();
        //};

        trackDialog.Show();
    }

    protected override async void OnPause()
    {
        base.OnPause();

        exoPlayer.PlayWhenReady = false;
        exoPlayer.Pause();

        await UpdateProgress();
    }

    public async Task UpdateProgress()
    {
        if (!CanSaveProgress)
            return;

        _playerSettings.WatchedEpisodes.TryGetValue(Episode.Link,
            out WatchedEpisode? watchedEpisode);

        watchedEpisode ??= new();

        watchedEpisode.Id = Episode.Id;
        watchedEpisode.AnimeName = Anime.Title;
        watchedEpisode.WatchedPercentage = (float)exoPlayer.CurrentPosition / exoPlayer.Duration * 100f;
        watchedEpisode.WatchedDuration = exoPlayer.CurrentPosition;

        _playerSettings.WatchedEpisodes.Remove(Episode.Link);
        _playerSettings.WatchedEpisodes.Add(Episode.Link, watchedEpisode);

        await _playerSettings.SaveAsync();
    }

    public async void PlayVideo(Video video)
    {
        if (selector is not null)
        {
            selector.Dismiss();
            selector = null;
        }

        await UpdateProgress();

        //var test = await Http.Client.SendHttpRequestAsync(video.VideoUrl, video.Headers);

        var videoUri = Android.Net.Uri.Parse(video.VideoUrl.Replace(" ", "%20"))!;

        var userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36";

        var headers = video.Headers.ToDictionary();
        headers.TryAdd("User-Agent", userAgent);

        var bandwidthMeter = new DefaultBandwidthMeter.Builder(this).Build();

        var httpClient = new OkHttpClient.Builder()
            .FollowSslRedirects(true)
            .FollowRedirects(true)
            .Build();

        //var dataSourceFactory = new DefaultHttpDataSource.Factory();
        var dataSourceFactory = new OkHttpDataSource.Factory(httpClient);

        dataSourceFactory.SetUserAgent(userAgent);
        dataSourceFactory.SetTransferListener(bandwidthMeter);
        dataSourceFactory.SetDefaultRequestProperties(headers);

        //dataSourceFactory.CreateDataSource();

        var extractorsFactory = new DefaultExtractorsFactory()
            .SetConstantBitrateSeekingEnabled(true);

        var simpleCache = VideoCache.GetInstance(this);

        var cacheFactory = new CacheDataSource.Factory();
        cacheFactory.SetCache(simpleCache);
        cacheFactory.SetUpstreamDataSourceFactory(dataSourceFactory);

        var mimeType = video?.Format switch
        {
            VideoType.M3u8 => MimeTypes.ApplicationM3u8,
            //VideoType.Dash => MimeTypes.ApplicationMpd,
            _ => MimeTypes.ApplicationMp4,
        };

        var mediaItem = new MediaItem.Builder()
            .SetUri(videoUri)!
            .SetMimeType(mimeType)!
            .Build();

        var type = Util.InferContentType(videoUri);
        var mediaSource = type switch
        {
            //case C.TypeDash:
            //    break;
            //case C.TypeSs:
            //    break;
            C.TypeHls => new HlsMediaSource.Factory(cacheFactory)
                .CreateMediaSource(mediaItem),
            //case C.TypeOther:
            //    break;
            _ => new ProgressiveMediaSource.Factory(cacheFactory, extractorsFactory)
                .CreateMediaSource(mediaItem),
        };

        exoPlayer.SetMediaSource(mediaSource);

        //exoPlayer.SetMediaItem(mediaItem);

        //exoPlayer.Prepare(mediaSource);
        exoPlayer.Prepare();
        exoPlayer.PlayWhenReady = true;

        _playerSettings.WatchedEpisodes.TryGetValue(Episode.Link,
            out WatchedEpisode? watchedEpisode);

        if (watchedEpisode is not null)
            exoPlayer.SeekTo(watchedEpisode.WatchedDuration);

        await Task.Run(async () =>
        {
            await LoadEpisode(GetNextEpisode());
            await LoadEpisode(GetPreviousEpisode());
        });
    }

    public void OnMediaItemTransition(MediaItem? mediaItem, int reason)
    {

    }

    public void OnAvailableCommandsChanged(Commands? availableCommands)
    {

    }

    public void OnPlaybackStateChanged(int playbackState)
    {
        IsBuffering = playbackState == IPlayer.StateBuffering;

        if (playbackState == StateReady)
        {
            var isPlaying = exoPlayer.IsPlaying;
        }
    }

    public void OnPlaybackSuppressionReasonChanged(int playbackSuppressionReason)
    {

    }

    public void OnRepeatModeChanged(int repeatMode)
    {

    }

    public void OnAudioSessionIdChanged(int audioSessionId)
    {

    }

    public void OnTracksChanged(Tracks? tracks)
    {
        //TODO: Bind exoplayer correctly to include "Groups" in tracks

        if (tracks is null)
            return;

        if (tracks.IsEmpty)
        {
            exoQuality.Visibility = ViewStates.Gone;
            return;
        }

        exoQuality.Visibility = ViewStates.Visible;

        if (exoQuality.HasOnClickListeners)
            return;

        exoQuality.Click += (s, e) =>
        {
            ShowM3U8TrackSelector();
        };
    }

    public void OnTimelineChanged(Timeline? timeline, int reason)
    {

    }

    public override void OnWindowFocusChanged(bool hasFocus)
    {
        base.OnWindowFocusChanged(hasFocus);

        if (hasFocus)
            this.HideSystemBars();
    }

    public void OnPlayerError(PlaybackException? error)
    {
        CanSaveProgress = false;

        //errorText.Text = "Video not found.";
        //errorText.Visibility = ViewStates.Visible;
    }

    public void OnIsPlayingChanged(bool isPlaying)
    {
        if (!IsBuffering)
        {
            playerView.KeepScreenOn = isPlaying;

            (exoplay.Drawable as IAnimatable)?.Start();

            if (!this.IsDestroyed)
            {
                if (isPlaying)
                {
                    Glide.With(this).Load(Resource.Drawable.anim_play_to_pause)
                        .Into(exoplay);
                }
                else
                {
                    Glide.With(this).Load(Resource.Drawable.anim_pause_to_play)
                        .Into(exoplay);
                }
            }
        }
    }

    public void OnLoadingChanged(bool isLoading)
    {

    }

    public void OnPlaybackParametersChanged(PlaybackParameters? playbackParameters)
    {

    }

    public void OnPositionDiscontinuity(int reason)
    {

    }

    public void OnSeekProcessed()
    {

    }

    public void OnShuffleModeEnabledChanged(bool shuffleModeEnabled)
    {

    }

    public void OnPlayerStateChanged(bool playWhenReady, int playbackState)
    {

    }

    public void OnPlayWhenReadyChanged(bool playWhenReady, int reason)
    {

    }

    public void OnEvents(IPlayer? player, Events? events)
    {

    }

    public void OnSurfaceSizeChanged(int width, int height)
    {

    }

    public void OnIsLoadingChanged(bool isLoading)
    {

    }

    public void OnVideoSizeChanged(VideoSize? videoSize)
    {

    }

    public void OnRenderedFirstFrame()
    {
        if (exoPlayer.VideoFormat is null)
            return;

        AspectRatio = new(exoPlayer.VideoFormat.Height, exoPlayer.VideoFormat.Width);

        VideoInfo.Text = $"{exoPlayer.VideoFormat.Width} x {exoPlayer.VideoFormat.Height}";

        if (!IsTimeStampsLoaded)
            LoadTimeStamps();

        CanSaveProgress = true;
    }

    public void OnPlayerErrorChanged(PlaybackException? error)
    {
        CanSaveProgress = false;

        //errorText.Text = "Video not found.";
        //errorText.Visibility = ViewStates.Visible;

        if (error is not null && error.Message is not null)
            this.ShowToast("Failed to play video");
    }

    public void OnDeviceVolumeChanged(int volume, bool muted)
    {

    }

    public void NetworkAvailable()
    {
        
    }

    public void NetworkUnavailable()
    {
        
    }

    public string? GetTrackName(Format? format)
    {
        if (format?.FrameRate > 0f)
        {
            if (format.FrameRate > 0f)
                return $"{format.Height}p";
            else
                return $"{format.Height}p (fps : N/A)";
        }

        return null;
    }

    public void OnTrackSelectionParametersChanged(TrackSelectionParameters? parameters)
    {

    }

#pragma warning disable CS0618
#pragma warning disable CS0672
    private void EnterPipMode()
    {
        try
        {
            if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
            {
                EnterPictureInPictureMode(new PictureInPictureParams.Builder()
                    .SetAspectRatio(AspectRatio)!
                    .Build()!);
            }
            else if (Build.VERSION.SdkInt >= BuildVersionCodes.N)
            {
                EnterPictureInPictureMode();
            }
        }
        catch (Exception e)
        {

        }
    }

    private void OnPiPChanged(bool isInPictureInPictureMode)
    {
        playerView.UseController = !isInPictureInPictureMode;

        if (isInPictureInPictureMode)
        {
            RequestedOrientation = ScreenOrientation.Unspecified;
            OrientationListener?.Disable();
        }
        else
        {
            OrientationListener?.Enable();
        }

        if (PlayAfterEnteringPipMode)
        {
            exoPlayer.Play();
        }
    }

    public override void OnPictureInPictureModeChanged(bool isInPictureInPictureMode)
    {
        OnPiPChanged(isInPictureInPictureMode);
        base.OnPictureInPictureModeChanged(isInPictureInPictureMode);
    }

    public override void OnPictureInPictureUiStateChanged(PictureInPictureUiState pipState)
    {
        OnPiPChanged(IsInPictureInPictureMode);
        base.OnPictureInPictureUiStateChanged(pipState);
    }

    public override void OnPictureInPictureModeChanged(bool isInPictureInPictureMode, Configuration? newConfig)
    {
        OnPiPChanged(isInPictureInPictureMode);
        base.OnPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
    }
#pragma warning restore CS0672
#pragma warning restore CS0618
}