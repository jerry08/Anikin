using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Android.Animation;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Graphics;
using Android.Graphics.Drawables;
using Android.OS;
using Android.Util;
using Android.Views;
using Android.Views.Animations;
using Android.Widget;
using AndroidX.CardView.Widget;
using AndroidX.Core.Content.Resources;
using AndroidX.Core.View;
using AniStream.Adapters;
using AniStream.Fragments;
using AniStream.Services;
using AniStream.Utils;
using AniStream.Utils.Downloading;
using AniStream.Utils.Extensions;
using AniStream.Utils.Listeners;
using Bumptech.Glide;
using Com.Google.Android.Exoplayer2;
using Com.Google.Android.Exoplayer2.Audio;
using Com.Google.Android.Exoplayer2.Ext.Okhttp;
using Com.Google.Android.Exoplayer2.Extractor;
using Com.Google.Android.Exoplayer2.Metadata;
using Com.Google.Android.Exoplayer2.Source;
using Com.Google.Android.Exoplayer2.Text;
using Com.Google.Android.Exoplayer2.Trackselection;
using Com.Google.Android.Exoplayer2.UI;
using Com.Google.Android.Exoplayer2.Upstream;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using Com.Google.Android.Exoplayer2.Util;
using Com.Google.Android.Exoplayer2.Video;
using Firebase;
using Firebase.Crashlytics;
using Google.Android.Material.Card;
using Juro.Models;
using Juro.Models.Anime;
using Juro.Models.Videos;
using Juro.Providers.Anilist;
using Juro.Providers.Anime;
using Juro.Providers.Aniskip;
using Square.OkHttp3;
using static Com.Google.Android.Exoplayer2.IPlayer;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using Configuration = Android.Content.Res.Configuration;
using Format = Com.Google.Android.Exoplayer2.Format;
using Handler = Android.OS.Handler;

namespace AniStream;

[Activity(Label = "VideoActivity", Theme = "@style/VideoPlayerTheme",
    ResizeableActivity = true, LaunchMode = LaunchMode.SingleTask, SupportsPictureInPicture = true,
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.SmallestScreenSize | ConfigChanges.ScreenLayout | ConfigChanges.Keyboard | ConfigChanges.KeyboardHidden)]
public class VideoActivity : ActivityBase, IPlayer.IListener, ITrackNameProvider
{
    private readonly IAnimeProvider _client = WeebUtils.AnimeClient;
    private readonly PlayerSettings _playerSettings = new();
    private readonly Handler _handler = new(Looper.MainLooper!);

    public CancellationTokenSource CancellationTokenSource { get; set; } = new();

    private IAnimeInfo Anime = default!;
    private Episode Episode = default!;
    private VideoSource? Video;
    private VideoServer? VideoServer;

    private IExoPlayer exoPlayer = default!;
    private StyledPlayerView playerView = default!;
    //private PlayerView playerView = default!;
    DefaultTrackSelector trackSelector = default!;

    private ProgressBar progressBar = default!;
    private ImageButton exoplay = default!;
    private ImageButton exoQuality = default!;
    private ImageButton DownloadButton = default!;
    //private int currentVideoIndex;
    //private LinearLayout controls = default!;
    private TextView animeTitle = default!;
    //private SpinnerNoSwipe episodeTitle = default!;
    private TextView episodeTitle = default!;
    //private TextView errorText = default!;
    private TextView VideoInfo = default!;
    private TextView VideoName = default!;
    private TextView ServerInfo = default!;

    private ImageButton PrevButton = default!;
    private ImageButton NextButton = default!;
    private ImageButton SourceButton = default!;

    private MaterialCardView ExoSkip = default!;
    private ImageButton ExoSkipOpEd = default!;
    private MaterialCardView SkipTimeButton = default!;
    private TextView SkipTimeText = default!;
    private TextView TimeStampText = default!;

    private bool IsPipEnabled { get; set; }
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

        FirebaseApp.InitializeApp(this);
        FirebaseCrashlytics.Instance.SetCrashlyticsCollectionEnabled(true);

        _playerSettings.Load();

        if (_playerSettings.AlwaysInLandscapeMode && Build.VERSION.SdkInt >= BuildVersionCodes.Gingerbread)
            RequestedOrientation = ScreenOrientation.SensorLandscape;

        var animeString = Intent!.GetStringExtra("anime");
        if (!string.IsNullOrEmpty(animeString))
            Anime = JsonSerializer.Deserialize<AnimeInfo>(animeString)!;

        var episodeString = Intent.GetStringExtra("episode");
        if (!string.IsNullOrEmpty(episodeString))
            Episode = JsonSerializer.Deserialize<Episode>(episodeString)!;

        var videoServerString = Intent.GetStringExtra("videoServer");
        if (!string.IsNullOrEmpty(videoServerString))
            VideoServer = JsonSerializer.Deserialize<VideoServer>(videoServerString)!;

        var bookmarkManager = new BookmarkManager("recently_watched");

        var isBooked = await bookmarkManager.IsBookmarked(Anime);
        if (isBooked)
            await bookmarkManager.RemoveBookmarkAsync(Anime);

        await bookmarkManager.SaveBookmarkAsync(Anime, true);

        animeTitle = FindViewById<TextView>(Resource.Id.exo_anime_title)!;
        episodeTitle = FindViewById<TextView>(Resource.Id.exo_ep_sel)!;

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        playerView = FindViewById<StyledPlayerView>(Resource.Id.player_view)!;
        exoplay = FindViewById<ImageButton>(Resource.Id.exo_play)!;
        exoQuality = FindViewById<ImageButton>(Resource.Id.exo_quality)!;
        progressBar = FindViewById<ProgressBar>(Resource.Id.exo_init_buffer)!;

        VideoInfo = FindViewById<TextView>(Resource.Id.exo_video_info)!;
        VideoName = FindViewById<TextView>(Resource.Id.exo_video_name)!;
        ServerInfo = FindViewById<TextView>(Resource.Id.exo_server_info)!;

        ServerInfo.Text = Anime.Site.ToString();

        VideoName.Text = VideoServer?.Name;
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
        SourceButton = FindViewById<ImageButton>(Resource.Id.exo_source)!;
        var subButton = FindViewById<ImageButton>(Resource.Id.exo_sub)!;
        DownloadButton = FindViewById<ImageButton>(Resource.Id.exo_download)!;
        var exoPip = FindViewById<ImageButton>(Resource.Id.exo_pip)!;
        ExoSkipOpEd = FindViewById<ImageButton>(Resource.Id.exo_skip_op_ed)!;
        SkipTimeButton = FindViewById<MaterialCardView>(Resource.Id.exo_skip_timestamp)!;
        SkipTimeText = FindViewById<TextView>(Resource.Id.exo_skip_timestamp_text)!;
        TimeStampText = FindViewById<TextView>(Resource.Id.exo_time_stamp_text)!;
        var exoSpeed = FindViewById<ImageButton>(Resource.Id.exo_playback_speed)!;
        var exoScreen = FindViewById<ImageButton>(Resource.Id.exo_screen)!;
        var exoSubtitle = FindViewById(Resource.Id.exo_subtitles)!;
        var exoSubtitleBtn = FindViewById(Resource.Id.exo_sub)!;

        var backButton = FindViewById<ImageButton>(Resource.Id.exo_back)!;
        var lockButton = FindViewById<ImageButton>(Resource.Id.exo_lock)!;

        // TODO: Implement these
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

        SourceButton.Click += (s, e) =>
        {
            selector = SelectorDialogFragment.NewInstance(Anime, Episode, this);
            selector.Show(SupportFragmentManager, "dialog");
        };

        backButton.Click += (s, e) =>
        {
            OnBackPressed();
        };

        ExoSkip.Click += (s, e) =>
        {
            exoPlayer.SeekTo(exoPlayer.CurrentPosition + 85000);
        };

        if (!_playerSettings.DoubleTap)
        {
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
        }

        playerView.ControllerShowTimeoutMs = 5000;

        playerView.FindViewById(Resource.Id.exo_full_area)!.Click += (s, e) =>
        {
            HandleController();
        };

        // Screen Gestures
        if (_playerSettings.DoubleTap)
        {
            var fastRewindGestureListener = new GesturesListener();
            fastRewindGestureListener.OnDoubleClick += (s, e) =>
            {
                Seek(false, e);
            };

            fastRewindGestureListener.OnSingleClick += (s, e) =>
            {
                HandleController();
            };

            var fastRewindDetector = new GestureDetector(this, fastRewindGestureListener);
            var rewindArea = FindViewById<View>(Resource.Id.exo_rewind_area)!;
            rewindArea.Clickable = true;
            rewindArea.Touch += (s, e) =>
            {
                e.Handled = false;
                fastRewindDetector.OnTouchEvent(e.Event!);
                rewindArea.PerformClick();
            };

            var fastForwardGestureListener = new GesturesListener();
            fastForwardGestureListener.OnDoubleClick += (s, e) =>
            {
                Seek(true, e);
            };

            fastForwardGestureListener.OnSingleClick += (s, e) =>
            {
                HandleController();
            };

            var fastForwardDetector = new GestureDetector(this, fastForwardGestureListener);
            var forwardArea = FindViewById<View>(Resource.Id.exo_forward_area)!;
            forwardArea.Clickable = true;
            forwardArea.Touch += (s, e) =>
            {
                e.Handled = false;
                fastForwardDetector.OnTouchEvent(e.Event!);
                forwardArea.PerformClick();
            };
        }

        // Play Pause
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

        DownloadButton.Click += async delegate
        {
            if (Video is not null)
                await new EpisodeDownloader().EnqueueAsync(Anime, Episode, Video);
        };

        if (_playerSettings.SelectServerBeforePlaying)
        {
            var videoString = Intent.GetStringExtra("video");
            if (!string.IsNullOrEmpty(videoString))
            {
                Video = JsonSerializer.Deserialize<VideoSource>(videoString)!;

                PlayVideo(Video);
            }
        }
        else
        {
            var progressBar = FindViewById<ProgressBar>(Resource.Id.exo_init_buffer)!;
            progressBar.Visibility = ViewStates.Visible;

            await SetEpisodeAsync(Episode.Id);
        }
    }

    private async Task SetEpisodeAsync(string episodeId)
    {
        CancellationTokenSource = new();

        DownloadButton.Visibility = ViewStates.Gone;

        try
        {
            var videoServers = await _client.GetVideoServersAsync(
                episodeId,
                CancellationTokenSource.Token
            );

            if (videoServers.Count == 0)
            {
                progressBar.Visibility = ViewStates.Gone;
                this.ToastString("No servers found");

                return;
            }

            var selectedVideoServer = videoServers
                .Find(x => x.Name?.ToLower().Contains("streamsb") == true
                    || x.Name?.ToLower().Contains("vidstream") == true
                    || x.Name?.Equals("mirror", StringComparison.OrdinalIgnoreCase) == true // Indonesian
                ) ?? videoServers[0];

            var videos = await _client.GetVideosAsync(selectedVideoServer);

            if (videos.Count == 0)
            {
                progressBar.Visibility = ViewStates.Gone;
                //this.ToastString("No videos found");
                this.ShowToast("No videos found");

                SourceButton.PerformClick();

                return;
            }

            VideoName.Text = selectedVideoServer.Name;

            PlayVideo(videos[0]);

            progressBar.Visibility = ViewStates.Gone;
            DownloadButton.Visibility = ViewStates.Visible;
        }
        catch
        {
            // Ignore
        }
    }

    private void HandleController()
    {
        if (Build.VERSION.SdkInt >= BuildVersionCodes.N && IsInPictureInPictureMode)
            return;

        var overshoot = AnimationUtils.LoadInterpolator(this, Resource.Animation.over_shoot);

        if (playerView.IsControllerFullyVisible)
        {
            ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_controller), "alpha", 1f, 0f)!
                .SetDuration(_playerSettings.ControllerDuration).Start();

            var animator1 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_bottom_cont), "translationY", 0f, 128f)!;
            animator1.SetInterpolator(overshoot);
            animator1.SetDuration(_playerSettings.ControllerDuration);
            animator1.Start();

            var animator2 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_timeline_cont), "translationY", 0f, 128f)!;
            animator2.SetInterpolator(overshoot);
            animator2.SetDuration(_playerSettings.ControllerDuration);
            animator2.Start();

            var animator3 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_top_cont), "translationY", 0f, -128f)!;
            animator3.SetInterpolator(overshoot);
            animator3.SetDuration(_playerSettings.ControllerDuration);
            animator3.Start();

            playerView.PostDelayed(() => playerView.HideController(), _playerSettings.ControllerDuration);
        }
        else
        {
            playerView.ShowController();

            ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_controller), "alpha", 0f, 1f)!
                .SetDuration(_playerSettings.ControllerDuration).Start();

            var animator1 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_bottom_cont), "translationY", 128f, 0f)!;
            animator1.SetInterpolator(overshoot);
            animator1.SetDuration(_playerSettings.ControllerDuration);
            animator1.Start();

            var animator2 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_timeline_cont), "translationY", 128f, 0f)!;
            animator2.SetInterpolator(overshoot);
            animator2.SetDuration(_playerSettings.ControllerDuration);
            animator2.Start();

            var animator3 = ObjectAnimator.OfFloat(playerView.FindViewById(Resource.Id.exo_top_cont), "translationY", -128f, 0f)!;
            animator3.SetInterpolator(overshoot);
            animator3.SetDuration(_playerSettings.ControllerDuration);
            animator3.Start();
        }
    }

    private void BuildExoplayer(CacheDataSource.Factory cacheFactory)
    {
        // Quality Track
        trackSelector = new DefaultTrackSelector(this);

        // Todo: Allow changing default video size in settings
        //trackSelector.SetParameters(
        //    (DefaultTrackSelector.Parameters.Builder?)trackSelector.BuildUponParameters()!
        //    .SetMinVideoSize(_playerSettings.MaxWidth ?? 720, _playerSettings.MaxHeight ?? 480)!
        //    .SetMaxVideoSize(1, 1)!
        //);

        exoPlayer = new IExoPlayer.Builder(this)
            .SetTrackSelector(trackSelector)!
            .SetMediaSourceFactory(new DefaultMediaSourceFactory(cacheFactory))!
            .Build()!;

        playerView.Player = exoPlayer;
        exoPlayer.AddListener(this);

        if (playerView.SubtitleView is not null)
        {
            playerView.SubtitleView.Alpha = 1f;
            playerView.SubtitleView.SetApplyEmbeddedFontSizes(false);

            var primaryColor = Color.White;
            var secondaryColor = Color.Black;
            var outline = CaptionStyleCompat.EdgeTypeOutline;
            var subBackground = Color.Transparent;
            var subWindow = Color.Transparent;
            var font = ResourcesCompat.GetFont(this, Resource.Font.poppins);

            var captionStyle = new CaptionStyleCompat(
                primaryColor,
                subBackground,
                subWindow,
                outline,
                secondaryColor,
                font
            );

            playerView.SubtitleView.SetStyle(captionStyle);

            playerView.SubtitleView.SetFixedTextSize(
                (int)ComplexUnitType.Sp,
                20f
            );
        }

        //progressBar.Visibility = ViewStates.Visible;
    }

    private System.Timers.Timer seekTimerF = new();
    private System.Timers.Timer seekTimerR = new();
    private long seekTimesF;
    private long seekTimesR;
    public void Seek(bool forward, MotionEvent? @event = null)
    {
        var rewindText = playerView.FindViewById<TextView>(Resource.Id.exo_fast_rewind_anim)!;
        var forwardText = playerView.FindViewById<TextView>(Resource.Id.exo_fast_forward_anim)!;
        var fastForwardCard = playerView.FindViewById<View>(Resource.Id.exo_fast_forward)!;
        var fastRewindCard = playerView.FindViewById<View>(Resource.Id.exo_fast_rewind)!;

        if (forward)
        {
            forwardText.Text = $"+{(_playerSettings.SeekTime / 1000) * ++seekTimesF}";
            _handler.Post(() =>
            {
                exoPlayer.SeekTo(exoPlayer.CurrentPosition + _playerSettings.SeekTime);
            });

            StartDoubleTapped(fastForwardCard, forwardText, forward, @event);

            seekTimerF.Stop();
            seekTimerF = new();
            seekTimerF.Interval = 850;

            seekTimerF.Elapsed += (s, e) =>
            {
                seekTimerF.Stop();
                StopDoubleTapped(fastForwardCard, forwardText);
                seekTimesF = 0;
            };

            seekTimerF.Start();
        }
        else
        {
            rewindText.Text = $"-{(_playerSettings.SeekTime / 1000) * ++seekTimesR}";
            _handler.Post(() =>
            {
                exoPlayer.SeekTo(exoPlayer.CurrentPosition - _playerSettings.SeekTime);
            });

            StartDoubleTapped(fastRewindCard, rewindText, forward, @event);

            seekTimerR.Stop();
            seekTimerR = new();
            seekTimerR.Interval = 850;

            seekTimerR.Elapsed += (s, e) =>
            {
                seekTimerR.Stop();
                StopDoubleTapped(fastRewindCard, rewindText);
                seekTimesR = 0;
            };

            seekTimerR.Start();
        }
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

        var allVideos = new List<VideoSource>();

        foreach (var server in videoServers)
        {
            try
            {
                allVideos.AddRange(await _client.GetVideosAsync(server));
            }
            catch { }
        }

        var epKey = episode.Link ?? episode.Id;

        if (!SelectorDialogFragment.Cache.ContainsKey(epKey))
        {
            var serverWithVideos = videoServers
                .ConvertAll(x => new ServerWithVideos(x, allVideos));

            SelectorDialogFragment.Cache.Add(epKey, serverWithVideos);
        }

        RunOnUiThread(SetNextAndPrev);
    }

    private void SetNextAndPrev()
    {
        PrevButton.Visibility = ViewStates.Visible;
        NextButton.Visibility = ViewStates.Visible;

        var prevEpisode = GetPreviousEpisode();
        var prevEpisodeKey = prevEpisode?.Link ?? prevEpisode?.Id;
        if (prevEpisode is not null
            && SelectorDialogFragment.Cache.ContainsKey(prevEpisodeKey!))
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
        var nextEpisodeKey = nextEpisode?.Link ?? nextEpisode?.Id;
        if (nextEpisode is not null
            && SelectorDialogFragment.Cache.ContainsKey(nextEpisodeKey!))
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

    public Episode? GetPreviousEpisode()
    {
        var currentEpisode = EpisodesActivity.Episodes.Find(x => x.Id == Episode.Id);
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

        CancellationTokenSource.Cancel();
        VideoCache.Release();
        //SetupExoPlayer();

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        //progressBar.Visibility = ViewStates.Visible;

        await SetEpisodeAsync(prevEpisode.Id);
        SetNextAndPrev();
    }

    public Episode? GetNextEpisode()
    {
        var currentEpisode = EpisodesActivity.Episodes.Find(x => x.Id == Episode.Id);
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

        CancellationTokenSource.Cancel();
        VideoCache.Release();
        //SetupExoPlayer();

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        //progressBar.Visibility = ViewStates.Visible;

        await SetEpisodeAsync(Episode.Id);
        SetNextAndPrev();
    }

    public override void OnBackPressed()
    {
        if (exoPlayer is not null)
        {
            exoPlayer.Stop();
            exoPlayer.Release();
        }

        CancellationTokenSource.Cancel();
        VideoCache.Release();

        base.OnBackPressed();
    }

    private List<Stamp> SkippedTimeStamps { get; set; } = new();
    private Stamp? CurrentTimeStamp { get; set; }
    private async void LoadTimeStamps()
    {
        if (IsTimeStampsLoaded || WeebUtils.AnimeSite != AnimeSites.GogoAnime)
            return;

        var client = new AnilistClient();

        try
        {
            var searchResults = await client.SearchAsync("ANIME", search: Anime.Title);
            if (searchResults is null)
                return;

            var animes = searchResults?.Results.Where(x => x.IdMal is not null).ToList();
            if (animes is null || animes.Count == 0)
                return;

            var media = await client.GetMediaDetailsAsync(animes[0]);
            if (media is null || media.IdMal is null)
                return;

            var timeStamps = await client.Aniskip.GetAsync(media.IdMal.Value, (int)Episode.Number, exoPlayer.Duration / 1000);
            if (timeStamps is null)
                return;

            SkippedTimeStamps.AddRange(timeStamps);

            var adGroups = new List<long>();
            for (var i = 0; i < timeStamps.Count; i++)
            {
                adGroups.Add((long)(timeStamps[i].Interval.StartTime * 1000));
                adGroups.Add((long)(timeStamps[i].Interval.EndTime * 1000));
            }

            var playedAdGroups = new List<bool>();
            for (var i = 0; i < timeStamps.Count; i++)
            {
                playedAdGroups.Add(false);
                playedAdGroups.Add(false);
            }

            playerView.SetExtraAdGroupMarkers(adGroups.ToArray(), playedAdGroups.ToArray());

            ExoSkipOpEd.Alpha = 1f;

            // Todo
            //ExoSkipOpEd.Visibility = ViewStates.Visible;

            if (_playerSettings.TimeStampsEnabled && _playerSettings.ShowTimeStampButton)
                UpdateTimeStamp();
        }
        catch { }
    }

    private void UpdateTimeStamp()
    {
        var playerCurrentTime = exoPlayer.CurrentPosition / 1000;
        CurrentTimeStamp = SkippedTimeStamps.Find(x => x.Interval.StartTime <= playerCurrentTime
            && playerCurrentTime < x.Interval.EndTime - 1);

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
            ExoSkip.Visibility = ViewStates.Visible;
        }

        _handler.PostDelayed(() =>
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

        if (exoPlayer is not null)
        {
            exoPlayer.PlayWhenReady = false;
            exoPlayer.Pause();
        }

        await UpdateProgress();
    }

    public async Task UpdateProgress()
    {
        if (!CanSaveProgress)
            return;

        _playerSettings.WatchedEpisodes.TryGetValue(Episode.Id,
            out var watchedEpisode);

        watchedEpisode ??= new();

        watchedEpisode.Id = Episode.Id;
        watchedEpisode.AnimeName = Anime.Title;
        watchedEpisode.WatchedPercentage = (float)exoPlayer.CurrentPosition / exoPlayer.Duration * 100f;
        watchedEpisode.WatchedDuration = exoPlayer.CurrentPosition;

        _playerSettings.WatchedEpisodes.Remove(Episode.Id);
        _playerSettings.WatchedEpisodes.Add(Episode.Id, watchedEpisode);

        _playerSettings.Save();
    }

    public async void PlayVideo(VideoSource video)
    {
        if (exoPlayer is not null)
        {
            exoPlayer.Pause();
            exoPlayer.Stop();
        }

        Video = video;

        if (selector is not null)
        {
            selector.Dismiss();
            selector = null;
        }

        await UpdateProgress();

        var videoUri = Android.Net.Uri.Parse(video.VideoUrl.Replace(" ", "%20"))!;

        var userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36";

        var headers = video.Headers;
        headers.TryAdd("User-Agent", userAgent);

        var bandwidthMeter = new DefaultBandwidthMeter.Builder(this).Build();

        var httpClient = new OkHttpClient.Builder()
            .FollowSslRedirects(true)
            .FollowRedirects(true)
            .Build();

        var dataSourceFactory = new OkHttpDataSource.Factory(httpClient);

        dataSourceFactory.SetUserAgent(userAgent);
        dataSourceFactory.SetTransferListener(bandwidthMeter);
        dataSourceFactory.SetDefaultRequestProperties(headers);

        var extractorsFactory = new DefaultExtractorsFactory()
            .SetConstantBitrateSeekingEnabled(true);

        var simpleCache = VideoCache.GetInstance(this);

        var cacheFactory = new CacheDataSource.Factory();
        cacheFactory.SetCache(simpleCache);
        cacheFactory.SetUpstreamDataSourceFactory(dataSourceFactory);

        var mimeType = video.Format switch
        {
            VideoType.M3u8 => MimeTypes.ApplicationM3u8,
            VideoType.Dash => MimeTypes.ApplicationMpd,
            _ => MimeTypes.ApplicationMp4,
        };

        var builder = new MediaItem.Builder()
            .SetUri(videoUri)!
            .SetMimeType(mimeType)!;

        if (video.Subtitles.Count > 0)
        {
            var defaultSubTitle = video.Subtitles
                .FirstOrDefault(x => x.Language?.ToLower() == "en"
                    || x.Language?.ToLower() == "english") ?? video.Subtitles[0];

            var subTitleMimeType = defaultSubTitle.Type switch
            {
                SubtitleType.VTT => MimeTypes.TextVtt,
                SubtitleType.ASS => MimeTypes.TextSsa,
                SubtitleType.SRT => MimeTypes.ApplicationSubrip,
                _ => MimeTypes.TextUnknown
            };

            var sub = new MediaItem.SubtitleConfiguration.Builder(
                Android.Net.Uri.Parse(defaultSubTitle.Url)
            ).SetSelectionFlags(C.SelectionFlagForced)!
            .SetMimeType(subTitleMimeType)!
            .Build()!;

            builder.SetSubtitleConfigurations(new List<MediaItem.SubtitleConfiguration>()
            {
                sub
            });
        }

        var mediaItem = builder.Build();

        BuildExoplayer(cacheFactory);

        exoPlayer!.SetMediaItem(mediaItem);

        exoPlayer.Prepare();
        exoPlayer.PlayWhenReady = true;

        _playerSettings.WatchedEpisodes.TryGetValue(Episode.Id,
            out var watchedEpisode);

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

    public void OnMediaMetadataChanged(MediaMetadata? mediaMetadata)
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

        exoQuality.Click += (s, e) => ShowM3U8TrackSelector();
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

        if (error?.Message is not null)
        {
            this.ShowToast("Failed to play video");

            SourceButton.PerformClick();
        }
    }

    public void OnDeviceVolumeChanged(int volume, bool muted)
    {
    }

    public void OnAudioAttributesChanged(AudioAttributes? audioAttributes)
    {
    }

    public void OnCues(CueGroup? cueGroup)
    {
    }

    public void OnDeviceInfoChanged(DeviceInfo? deviceInfo)
    {
    }

    public void OnMaxSeekToPreviousPositionChanged(long maxSeekToPreviousPositionMs)
    {
    }

    public void OnMetadata(Metadata? metadata)
    {
    }

    public void OnPlaylistMetadataChanged(MediaMetadata? mediaMetadata)
    {
    }

    public void OnSeekBackIncrementChanged(long seekBackIncrementMs)
    {
    }

    public void OnSeekForwardIncrementChanged(long seekForwardIncrementMs)
    {
    }

    public void OnSkipSilenceEnabledChanged(bool skipSilenceEnabled)
    {
    }

    public void OnVolumeChanged(float volume)
    {
        throw new NotImplementedException();
    }

    public string? GetTrackName(Format? format)
    {
        if (format?.FrameRate > 0f)
        {
            return format.FrameRate > 0f ? $"{format.Height}p" : $"{format.Height}p (fps : N/A)";
        }

        return null;
    }

    public void OnTrackSelectionParametersChanged(TrackSelectionParameters? parameters)
    {
    }

    private void StartDoubleTapped(
        View view,
        TextView textView,
        bool forward,
        MotionEvent? @event = null)
    {
        ObjectAnimator.OfFloat(textView, "alpha", 1f, 1f)!.SetDuration(600).Start();
        ObjectAnimator.OfFloat(textView, "alpha", 0f, 1f)!.SetDuration(150).Start();

        if (textView.GetCompoundDrawables()?[1] is IAnimatable animatable && !animatable.IsRunning)
            animatable.Start();

        if (@event is not null)
        {
            playerView.HideController();
            view.CircularReveal((int)@event.GetX(), (int)@event.GetY(), !forward, 800);
            ObjectAnimator.OfFloat(view, "alpha", 1f, 1f)!.SetDuration(800).Start();
            ObjectAnimator.OfFloat(view, "alpha", 0f, 1f)!.SetDuration(300).Start();
        }
    }

    private void StopDoubleTapped(View view, TextView textView)
    {
        _handler.Post(() =>
        {
            ObjectAnimator.OfFloat(view, "alpha", view.Alpha, 0f)!.SetDuration(150).Start();
            ObjectAnimator.OfFloat(textView, "alpha", 1f, 0f)!.SetDuration(150).Start();
        });
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
        catch
        {
            // Ignore
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