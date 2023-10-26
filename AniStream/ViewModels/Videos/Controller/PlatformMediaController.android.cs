using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using Android.Animation;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Graphics.Drawables;
using Android.Media.Audiofx;
using Android.OS;
using Android.Support.V4.Media.Session;
using Android.Util;
using Android.Views;
using Android.Views.Animations;
using Android.Widget;
using AndroidX.CardView.Widget;
using AndroidX.Core.View;
using AniStream.Services;
using AniStream.Utils.Extensions;
using AniStream.Utils.Listeners;
using AniStream.ViewModels;
using AniStream.Views.BottomSheets;
using Berry.Maui.Core;
using Berry.Maui.Core.Handlers;
using Bumptech.Glide;
using Com.Google.Android.Exoplayer2;
using Com.Google.Android.Exoplayer2.Audio;
using Com.Google.Android.Exoplayer2.Ext.Mediasession;
using Com.Google.Android.Exoplayer2.Metadata;
using Com.Google.Android.Exoplayer2.Text;
using Com.Google.Android.Exoplayer2.Trackselection;
using Com.Google.Android.Exoplayer2.UI;
using Com.Google.Android.Exoplayer2.Video;
using CommunityToolkit.Maui.Alerts;
using Google.Android.Material.Card;
using Jita.AniList;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Juro.Providers.Aniskip;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Platform;
using Microsoft.Maui.Storage;
using static Com.Google.Android.Exoplayer2.IPlayer;
using AudioFocus = Android.Media.AudioFocus;
using Format = Com.Google.Android.Exoplayer2.Format;
using Handler = Android.OS.Handler;
using Media = Jita.AniList.Models.Media;
using Shell = Microsoft.Maui.Controls.Shell;

namespace AniStream;

public class PlatformMediaController : Java.Lang.Object, IPlayer.IListener, ITrackNameProvider
{
    private readonly PlayerSettings _playerSettings = new();
    private readonly VideoPlayerViewModel _playerViewModel;
    private readonly Handler _handler = new(Looper.MainLooper!);

    public IMediaElement MediaElement { get; private set; } = default!;

    public CancellationTokenSource CancellationTokenSource { get; set; } = new();

    private readonly Media _media;
    private IAnimeInfo Anime = default!;
    private Episode Episode = default!;
    private VideoSource? Video;
    private VideoServer? VideoServer;

    private IExoPlayer exoPlayer = default!;
    private StyledPlayerView playerView = default!;
    //private PlayerView playerView = default!;
    DefaultTrackSelector trackSelector = default!;

    //private MediaSession? MediaSession { get; set; }
    private MediaSessionCompat? MediaSession { get; set; }
    private MediaSessionConnector? MediaSessionConnector { get; set; }

    //private ProgressBar progressBar = default!;
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

    //private SelectorDialogFragment? selector;

    private bool IsBuffering { get; set; } = true;

    private bool IsTimeStampsLoaded { get; set; }

    private bool IsSeeking { get; set; }
    private bool IsSeekingBackward { get; set; }
    private bool IsSeekingForward { get; set; }

    public PlatformMediaController(VideoPlayerViewModel playerViewModel, IAnimeInfo anime, Episode episode, VideoServer videoServer, Media media)
    {
        _playerViewModel = playerViewModel;
        Anime = anime;
        Episode = episode;
        VideoServer = videoServer;
        _media = media;

        _playerSettings.Load();

        WindowCompat.SetDecorFitsSystemWindows(Platform.CurrentActivity.Window!, false);
        Platform.CurrentActivity.HideSystemBars();

        if (_playerSettings.AlwaysInLandscapeMode && Build.VERSION.SdkInt >= BuildVersionCodes.Gingerbread)
            Platform.CurrentActivity.RequestedOrientation = ScreenOrientation.SensorLandscape;
    }

    #region Setup
    public void OnLoaded(IMediaElement mediaElement)
    {
        MediaElement = mediaElement;

        var handler = (MediaElementHandler)mediaElement.Handler;
        playerView = handler.PlatformView.GetFirstChildOfType<StyledPlayerView>()!;
        var styledPlayerControlView = handler.PlatformView.GetFirstChildOfType<StyledPlayerControlView>()!;
        styledPlayerControlView.AnimationEnabled = false;

        //var view = (MauiMediaElement)mediaElement.ToPlatform(mediaElement.Handler.MauiContext);
        //StyledPlayerView = (StyledPlayerView?)view.playe;

        if (Platform.CurrentActivity is MainActivity mainActivity)
        {
            mainActivity.MediaElementController = this;
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (exoPlayer is not null)
        {
            exoPlayer.Stop();
            exoPlayer.Release();
        }

        CancellationTokenSource.Cancel();

        Platform.CurrentActivity.RequestedOrientation = ScreenOrientation.Unspecified;
        Platform.CurrentActivity.ShowSystemBars();

        if (Platform.CurrentActivity is MainActivity mainActivity)
        {
            mainActivity.MediaElementController = null;
        }

        try
        {
            var dir = System.IO.Path.Combine(FileSystem.CacheDirectory, "exoplayer");
            System.IO.Directory.Delete(dir, true);
        }
        catch
        {
            // Ignore
        }
    }
    #endregion

    public void Initialize()
    {
        exoPlayer = (IExoPlayer)playerView.Player;
        exoPlayer.AddListener(this);

        try
        {
            MediaSession = new(Platform.CurrentActivity, "AniStreamMediaSession");

            MediaSessionConnector = new MediaSessionConnector(MediaSession);
            MediaSessionConnector.SetPlayer(exoPlayer);
        }
        catch (Exception e)
        {
            Snackbar.Make(e.Message).Show();
        }

        //var bookmarkManager = new BookmarkManager("recently_watched");
        //
        //var isBooked = await bookmarkManager.IsBookmarked(Anime);
        //if (isBooked)
        //    await bookmarkManager.RemoveBookmarkAsync(Anime);
        //
        //await bookmarkManager.SaveBookmarkAsync(Anime, true);

        animeTitle = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_anime_title)!;
        episodeTitle = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_ep_sel)!;

        animeTitle.Text = Anime.Title;
        episodeTitle.Text = Episode.Name;

        exoplay = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_play)!;
        exoQuality = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_quality)!;
        //progressBar = Platform.CurrentActivity.FindViewById<ProgressBar>(Resource.Id.exo_init_buffer)!;

        VideoInfo = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_video_info)!;
        VideoName = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_video_name)!;
        ServerInfo = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_server_info)!;

        ServerInfo.Text = Anime.Site.ToString();

        VideoName.Text = VideoServer?.Name;
        VideoName.Selected = true;

        VideoName.Text = "My server test";

        ExoSkip = Platform.CurrentActivity.FindViewById<MaterialCardView>(Resource.Id.exo_skip)!;

        PrevButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_prev_ep)!;
        NextButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_next_ep)!;

        //PrevButton.Click += (s, e) => PlayPreviousEpisode();
        //
        //NextButton.Click += (s, e) => PlayNextEpisode();

        var audioManager = (Android.Media.AudioManager?)Platform.CurrentActivity.GetSystemService(Context.AudioService);
        //var audioManager = Android.Media.AudioManager.FromContext(this);

        var audioFocusChangeListener = new AudioFocusChangeListener();

        audioFocusChangeListener.OnAudioFocusChanged += (_, focus) =>
        {
            switch (focus)
            {
                case AudioFocus.Loss:
                case AudioFocus.LossTransient:
                    if (exoPlayer?.IsPlaying == true)
                    {
                        exoPlayer.Pause();
                    }
                    break;
            }
        };

        if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
        {
            var audioAttributes = new Android.Media.AudioAttributes.Builder()
                .SetUsage(Android.Media.AudioUsageKind.Media)!
                .SetContentType(Android.Media.AudioContentType.Movie)!
                .Build()!;

            var focusRequest = new Android.Media.AudioFocusRequestClass.Builder(AudioFocus.Gain)
                .SetAudioAttributes(audioAttributes)
                .SetAcceptsDelayedFocusGain(true)
                .SetOnAudioFocusChangeListener(audioFocusChangeListener)
                .Build()!;

            audioManager?.RequestAudioFocus(focusRequest);
        }
        else
        {
#pragma warning disable CA1422
            audioManager!.RequestAudioFocus(
                audioFocusChangeListener,
                (Android.Media.Stream)ContentType.Movie,
                //Android.Media.Stream.Music,
                AudioFocus.Gain
            );
#pragma warning restore CA1422
        }

        var settingsButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_settings)!;
        SourceButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_source)!;
        var subButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_sub)!;
        DownloadButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_download)!;
        var exoPip = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_pip)!;
        ExoSkipOpEd = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_skip_op_ed)!;
        SkipTimeButton = Platform.CurrentActivity.FindViewById<MaterialCardView>(Resource.Id.exo_skip_timestamp)!;
        SkipTimeText = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_skip_timestamp_text)!;
        TimeStampText = Platform.CurrentActivity.FindViewById<TextView>(Resource.Id.exo_time_stamp_text)!;
        var exoSpeed = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_playback_speed)!;
        var exoScreen = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_screen)!;
        var exoSubtitle = Platform.CurrentActivity.FindViewById(Resource.Id.exo_subtitles)!;
        var exoSubtitleBtn = Platform.CurrentActivity.FindViewById(Resource.Id.exo_sub)!;

        var backButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_back)!;
        var lockButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_lock)!;

        // TODO: Implement these
        settingsButton.Visibility = ViewStates.Gone;
        subButton.Visibility = ViewStates.Gone;
        lockButton.Visibility = ViewStates.Gone;

        //SetNextAndPrev();

        //if (Android.Provider.Settings.System.GetInt(ContentResolver, Android.Provider.Settings.System.AccelerometerRotation, 0) != 1)
        //{
        //
        //}

        if (Build.VERSION.SdkInt >= BuildVersionCodes.N)
        {
            IsPipEnabled = Platform.CurrentActivity.PackageManager!.HasSystemFeature(PackageManager.FeaturePictureInPicture);

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
                    Platform.CurrentActivity.ToastString("Original");
                    break;
                case PlayerResizeMode.Zoom:
                    playerView.ResizeMode = AspectRatioFrameLayout.ResizeModeZoom;
                    Platform.CurrentActivity.ToastString("Zoom");
                    break;
                case PlayerResizeMode.Stretch:
                    playerView.ResizeMode = AspectRatioFrameLayout.ResizeModeFill;
                    Platform.CurrentActivity.ToastString("Stretch");
                    break;
                default:
                    Platform.CurrentActivity.ToastString("Original");
                    break;
            }
        };

        exoSpeed.Click += async (_, _) =>
        {
            await _playerViewModel.ShowSpeedSelector();
        };

        SourceButton.Click += async (s, e) =>
        {
            //selector = SelectorDialogFragment.NewInstance(Anime, Episode, this);
            //selector.Show(SupportFragmentManager, "dialog");

            var sheet = new EpisodeSelectionSheet();
            sheet.BindingContext = new VideoSourceViewModel(sheet, Anime, Episode, _media);

            await sheet.ShowAsync();
        };

        backButton.Click += async (_, _) => await Shell.Current.Navigation.PopAsync();

        ExoSkip.Click += (s, e) => exoPlayer.SeekTo(exoPlayer.CurrentPosition + 85000);

        if (!_playerSettings.DoubleTap)
        {
            var fastForwardCont = Platform.CurrentActivity.FindViewById<CardView>(Resource.Id.exo_fast_forward_button_cont)!;
            var fastRewindCont = Platform.CurrentActivity.FindViewById<CardView>(Resource.Id.exo_fast_rewind_button_cont)!;
            var fastForwardButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_fast_forward_button)!;
            var rewindButton = Platform.CurrentActivity.FindViewById<ImageButton>(Resource.Id.exo_fast_rewind_button)!;

            fastForwardCont.Visibility = ViewStates.Visible;
            fastRewindCont.Visibility = ViewStates.Visible;

            fastForwardButton.Click += (s, e)
                => exoPlayer.SeekTo(exoPlayer.CurrentPosition + _playerSettings.SeekTime);

            rewindButton.Click += (s, e)
                => exoPlayer.SeekTo(exoPlayer.CurrentPosition - _playerSettings.SeekTime);
        }

        //playerView.ControllerShowTimeoutMs = 5000;

        playerView.FindViewById(Resource.Id.exo_full_area)!.Click += (s, e)
            => HandleController();

        // Screen Gestures
        if (_playerSettings.DoubleTap)
        {
            var fastRewindGestureListener = new GesturesListener();
            fastRewindGestureListener.OnDoubleClick += (_, e) => DoubleTap(false, e);

            fastRewindGestureListener.OnSingleClick += (_, e) =>
            {
                if (IsSeeking && !IsSeekingForward)
                    DoubleTap(false, e);
                else
                    HandleController();
            };

            var fastRewindDetector = new GestureDetector(Platform.CurrentActivity, fastRewindGestureListener);
            var rewindArea = Platform.CurrentActivity.FindViewById<View>(Resource.Id.exo_rewind_area)!;
            rewindArea.Clickable = true;
            rewindArea.Touch += (_, e) =>
            {
                fastRewindDetector.OnTouchEvent(e.Event!);
                rewindArea.PerformClick();
                e.Handled = true;
            };

            var fastForwardGestureListener = new GesturesListener();
            fastForwardGestureListener.OnDoubleClick += (_, e) => DoubleTap(true, e);

            fastForwardGestureListener.OnSingleClick += (_, e) =>
            {
                if (IsSeeking && !IsSeekingBackward)
                    DoubleTap(true, e);
                else
                    HandleController();
            };

            var fastForwardDetector = new GestureDetector(Platform.CurrentActivity, fastForwardGestureListener);
            var forwardArea = Platform.CurrentActivity.FindViewById<View>(Resource.Id.exo_forward_area)!;
            forwardArea.Clickable = true;
            forwardArea.Touch += (s, e) =>
            {
                fastForwardDetector.OnTouchEvent(e.Event!);
                forwardArea.PerformClick();
                e.Handled = true;
            };
        }

        // Play Pause
        exoplay.Click += (s, e) =>
        {
            (exoplay.Drawable as IAnimatable)?.Start();

            if (exoPlayer.IsPlaying)
            {
                Glide.With(Platform.CurrentActivity).Load(Resource.Drawable.anim_play_to_pause)
                    .Into(exoplay);

                exoPlayer.Pause();
            }
            else
            {
                Glide.With(Platform.CurrentActivity).Load(Resource.Drawable.anim_pause_to_play)
                    .Into(exoplay);

                exoPlayer.Play();
            }
        };

        DownloadButton.Click += async (_, _) =>
        {
            //if (Video is not null)
            //    await new EpisodeDownloader().EnqueueAsync(Anime, Episode, Video);
        };
    }

    private void DoubleTap(bool forward, MotionEvent @event) => Seek(forward, @event);

    private void HandleController()
    {
        if (Build.VERSION.SdkInt >= BuildVersionCodes.N && Platform.CurrentActivity.IsInPictureInPictureMode)
            return;

        var overshoot = AnimationUtils.LoadInterpolator(Platform.CurrentActivity, Resource.Animation.over_shoot);

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

    /*private void BuildExoplayer(CacheDataSource.Factory cacheFactory)
    {
        // Quality Track
        trackSelector = new DefaultTrackSelector(Platform.CurrentActivity);

        // Todo: Allow changing default video size in settings
        //trackSelector.SetParameters(
        //    (DefaultTrackSelector.Parameters.Builder?)trackSelector.BuildUponParameters()!
        //    .SetMinVideoSize(_playerSettings.MaxWidth ?? 720, _playerSettings.MaxHeight ?? 480)!
        //    .SetMaxVideoSize(1, 1)!
        //);

        exoPlayer = new IExoPlayer.Builder(Platform.CurrentActivity)
            .SetTrackSelector(trackSelector)!
            .SetMediaSourceFactory(new DefaultMediaSourceFactory(cacheFactory))!
            .Build()!;

        playerView.Player = exoPlayer;

        try
        {
            MediaSession = new(Platform.CurrentActivity, "AniStreamMediaSession");

            MediaSessionConnector = new MediaSessionConnector(MediaSession);
            MediaSessionConnector.SetPlayer(exoPlayer);
        }
        catch (Exception e)
        {
            Platform.CurrentActivity.ShowToast(e.Message);
        }

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
            var font = ResourcesCompat.GetFont(Platform.CurrentActivity, Resource.Font.poppins);

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
    }*/

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

        View card;
        TextView text;

        if (forward)
        {
            forwardText.Text = $"+{(_playerSettings.SeekTime / 1000) * ++seekTimesF}";

            _handler.Post(() => exoPlayer.SeekTo(exoPlayer.CurrentPosition + _playerSettings.SeekTime));

            card = fastForwardCard;
            text = forwardText;
        }
        else
        {
            rewindText.Text = $"-{(_playerSettings.SeekTime / 1000) * ++seekTimesR}";

            _handler.Post(() => exoPlayer.SeekTo(exoPlayer.CurrentPosition - _playerSettings.SeekTime));

            card = fastRewindCard;
            text = rewindText;
        }

        var showCardAnim = ObjectAnimator.OfFloat(card, "alpha", 0f, 1f)!.SetDuration(300);
        var showTextAnim = ObjectAnimator.OfFloat(text, "alpha", 0f, 1f)!.SetDuration(150);

        void StartAnim()
        {
            showTextAnim!.Start();

            if (text.GetCompoundDrawables()?[1] is IAnimatable animatable
                && !animatable.IsRunning)
            {
                animatable.Start();
            }

            if (!IsSeeking && @event is not null)
            {
                playerView.HideController();
                card.CircularReveal((int)@event.GetX(), (int)@event.GetY(), !forward, 800);
                showCardAnim!.Start();
            }
        }

        void StopAnim()
        {
            _handler.Post(() =>
            {
                showCardAnim?.Cancel();
                showTextAnim?.Cancel();
                ObjectAnimator.OfFloat(card, "alpha", card.Alpha, 0f)?.SetDuration(150).Start();
                ObjectAnimator.OfFloat(text, "alpha", 1f, 0f)?.SetDuration(150).Start();
            });
        }

        StartAnim();

        IsSeeking = true;

        if (forward)
        {
            IsSeekingForward = true;

            seekTimerF.Stop();
            seekTimerF = new()
            {
                Interval = 850,
                AutoReset = false
            };

            seekTimerF.Elapsed += (s, e) =>
            {
                IsSeeking = false;
                IsSeekingForward = false;
                seekTimerF.Stop();
                StopAnim();
                seekTimesF = 0;
            };

            seekTimerF.Start();
        }
        else
        {
            IsSeekingBackward = true;

            seekTimerR.Stop();
            seekTimerR = new()
            {
                Interval = 850,
                AutoReset = false
            };

            seekTimerR.Elapsed += (s, e) =>
            {
                IsSeeking = false;
                IsSeekingBackward = false;
                seekTimerR.Stop();
                StopAnim();
                seekTimesR = 0;
            };

            seekTimerR.Start();
        }
    }


    ///// <summary>
    ///// Load next or previous episode
    ///// </summary>
    ///// <param name="episode">Next or previous episode</param>
    //private async Task LoadEpisode(Episode? episode)
    //{
    //    if (episode is null) return;
    //
    //    var videoServers = await _client.GetVideoServersAsync(episode.Id);
    //    if (videoServers.Count == 0)
    //        return;
    //
    //    var allVideos = new List<VideoSource>();
    //
    //    foreach (var server in videoServers)
    //    {
    //        try
    //        {
    //            allVideos.AddRange(await _client.GetVideosAsync(server));
    //        }
    //        catch { }
    //    }
    //
    //    var epKey = episode.Link ?? episode.Id;
    //
    //    if (!SelectorDialogFragment.Cache.ContainsKey(epKey))
    //    {
    //        var serverWithVideos = videoServers
    //            .ConvertAll(x => new ServerWithVideos(x, allVideos));
    //
    //        SelectorDialogFragment.Cache.Add(epKey, serverWithVideos);
    //    }
    //
    //    RunOnUiThread(SetNextAndPrev);
    //}
    //
    //private void SetNextAndPrev()
    //{
    //    PrevButton.Visibility = ViewStates.Visible;
    //    NextButton.Visibility = ViewStates.Visible;
    //
    //    var prevEpisode = GetPreviousEpisode();
    //    var prevEpisodeKey = prevEpisode?.Link ?? prevEpisode?.Id;
    //    if (prevEpisode is not null
    //        && SelectorDialogFragment.Cache.ContainsKey(prevEpisodeKey!))
    //    {
    //        PrevButton.Enabled = true;
    //        PrevButton.Alpha = 1f;
    //    }
    //    else
    //    {
    //        PrevButton.Enabled = false;
    //        PrevButton.Alpha = 0.5f;
    //    }
    //
    //    var nextEpisode = GetNextEpisode();
    //    var nextEpisodeKey = nextEpisode?.Link ?? nextEpisode?.Id;
    //    if (nextEpisode is not null
    //        && SelectorDialogFragment.Cache.ContainsKey(nextEpisodeKey!))
    //    {
    //        NextButton.Enabled = true;
    //        NextButton.Alpha = 1f;
    //    }
    //    else
    //    {
    //        NextButton.Enabled = false;
    //        NextButton.Alpha = 0.5f;
    //    }
    //}
    //
    //public Episode? GetPreviousEpisode()
    //{
    //    var currentEpisode = EpisodesActivity.Episodes.Find(x => x.Id == Episode.Id);
    //    if (currentEpisode is null)
    //        return null;
    //
    //    var index = EpisodesActivity.Episodes.OrderBy(x => x.Number).ToList()
    //        .IndexOf(currentEpisode);
    //
    //    var prevEpisode = EpisodesActivity.Episodes.OrderBy(x => x.Number)
    //        .ElementAtOrDefault(index - 1);
    //
    //    return prevEpisode;
    //}
    //
    //private async void PlayPreviousEpisode()
    //{
    //    var prevEpisode = GetPreviousEpisode();
    //    if (prevEpisode is null)
    //        return;
    //
    //    Episode = prevEpisode;
    //
    //    exoPlayer.Pause();
    //    await UpdateProgress();
    //
    //    Episode = prevEpisode;
    //
    //    exoPlayer.Stop();
    //    exoPlayer.SeekTo(0);
    //    //exoPlayer.Release();
    //
    //    CancellationTokenSource.Cancel();
    //    VideoCache.Release();
    //    //SetupExoPlayer();
    //
    //    animeTitle.Text = Anime.Title;
    //    episodeTitle.Text = Episode.Name;
    //
    //    //progressBar.Visibility = ViewStates.Visible;
    //
    //    await SetEpisodeAsync(prevEpisode.Id);
    //    SetNextAndPrev();
    //}
    //
    //public Episode? GetNextEpisode()
    //{
    //    var currentEpisode = EpisodesActivity.Episodes.Find(x => x.Id == Episode.Id);
    //    if (currentEpisode is null)
    //        return null;
    //
    //    var index = EpisodesActivity.Episodes.OrderBy(x => x.Number).ToList()
    //        .IndexOf(currentEpisode);
    //
    //    var nextEpisode = EpisodesActivity.Episodes.OrderBy(x => x.Number)
    //        .ElementAtOrDefault(index + 1);
    //
    //    return nextEpisode;
    //}
    //
    //private async void PlayNextEpisode()
    //{
    //    var nextEpisode = GetNextEpisode();
    //    if (nextEpisode is null)
    //        return;
    //
    //    exoPlayer.Pause();
    //    await UpdateProgress();
    //
    //    Episode = nextEpisode;
    //
    //    exoPlayer.Stop();
    //    exoPlayer.SeekTo(0);
    //    //exoPlayer.Release();
    //
    //    CancellationTokenSource.Cancel();
    //    VideoCache.Release();
    //    //SetupExoPlayer();
    //
    //    animeTitle.Text = Anime.Title;
    //    episodeTitle.Text = Episode.Name;
    //
    //    //progressBar.Visibility = ViewStates.Visible;
    //
    //    await SetEpisodeAsync(Episode.Id);
    //    SetNextAndPrev();
    //}

    private List<Stamp> SkippedTimeStamps { get; set; } = new();
    private Stamp? CurrentTimeStamp { get; set; }
    private async void LoadTimeStamps()
    {
        if (IsTimeStampsLoaded)
            return;

        var client = new AniClient();

        try
        {
            var searchResults = await client.SearchMediaAsync(new Jita.AniList.Parameters.SearchMediaFilter()
            {
                Type = Jita.AniList.Models.MediaType.Anime,
                Query = Anime.Title
            });
            if (searchResults is null)
                return;

            var animes = searchResults?.Data.Where(x => x.MalId is not null).ToList();
            if (animes is null || animes.Count == 0)
                return;

            var media = await client.GetMediaAsync(animes[0].Id);
            if (media is null || media.MalId is null)
                return;

            var aniskipClient = new AniskipClient();

            var timeStamps = await aniskipClient.GetAsync(media.MalId.Value, (int)Episode.Number, exoPlayer.Duration / 1000);
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

        var trackSelectionDialogBuilder = new TrackSelectionDialogBuilder(
            Platform.CurrentActivity,
            new Java.Lang.String("Available Qualities"), exoPlayer, C.TrackTypeVideo);

        //trackSelectionDialogBuilder.SetTheme(Resource.Style.DialogTheme);
        //trackSelectionDialogBuilder.SetTrackNameProvider(this);

        var trackDialog = trackSelectionDialogBuilder.Build()!;
        trackDialog.DismissEvent += (s, e) =>
        {
            Platform.CurrentActivity.HideSystemBars();
        };

        trackDialog.Show();
    }

    //public async Task UpdateProgress()
    //{
    //    if (!CanSaveProgress)
    //        return;
    //
    //    _playerSettings.WatchedEpisodes.TryGetValue(Episode.Id,
    //        out var watchedEpisode);
    //
    //    watchedEpisode ??= new();
    //
    //    watchedEpisode.Id = Episode.Id;
    //    watchedEpisode.AnimeName = Anime.Title;
    //    watchedEpisode.WatchedPercentage = (float)exoPlayer.CurrentPosition / exoPlayer.Duration * 100f;
    //    watchedEpisode.WatchedDuration = exoPlayer.CurrentPosition;
    //
    //    _playerSettings.WatchedEpisodes.Remove(Episode.Id);
    //    _playerSettings.WatchedEpisodes.Add(Episode.Id, watchedEpisode);
    //
    //    _playerSettings.Save();
    //}
    //
    //public async void PlayVideo(VideoSource video)
    //{
    //    if (exoPlayer is not null)
    //    {
    //        exoPlayer.Pause();
    //        exoPlayer.Stop();
    //    }
    //
    //    Video = video;
    //
    //    await UpdateProgress();
    //
    //    _playerSettings.WatchedEpisodes.TryGetValue(Episode.Id,
    //        out var watchedEpisode);
    //
    //    if (watchedEpisode is not null)
    //        exoPlayer.SeekTo(watchedEpisode.WatchedDuration);
    //
    //    //await Task.Run(async () =>
    //    //{
    //    //    await LoadEpisode(GetNextEpisode());
    //    //    await LoadEpisode(GetPreviousEpisode());
    //    //});
    //}

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

        //if (playbackState == IPlayer.StateEnded)
        //    PlayNextEpisode();
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

    //public override void OnWindowFocusChanged(bool hasFocus)
    //{
    //    base.OnWindowFocusChanged(hasFocus);
    //
    //    if (hasFocus)
    //        Platform.CurrentActivity.HideSystemBars();
    //}

    public void OnPlayerError(PlaybackException? error)
    {
        //CanSaveProgress = false;
    }

    public void OnIsPlayingChanged(bool isPlaying)
    {
        if (!IsBuffering)
        {
            playerView.KeepScreenOn = isPlaying;

            (exoplay.Drawable as IAnimatable)?.Start();

            if (isPlaying)
            {
                Glide.With(Platform.CurrentActivity).Load(Resource.Drawable.anim_play_to_pause)
                    .Into(exoplay);
            }
            else
            {
                Glide.With(Platform.CurrentActivity).Load(Resource.Drawable.anim_pause_to_play)
                    .Into(exoplay);
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

        //CanSaveProgress = true;
    }

    public void OnPlayerErrorChanged(PlaybackException? error)
    {
        //CanSaveProgress = false;

        //errorText.Text = "Video not found.";
        //errorText.Visibility = ViewStates.Visible;

        if (error?.Message is not null)
        {
            Platform.CurrentActivity.ShowToast("Failed to play video");

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
        //throw new NotImplementedException();
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

#pragma warning disable CS0618, CS0672, CA1422
    private void EnterPipMode()
    {
        try
        {
            if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
            {
                Platform.CurrentActivity.EnterPictureInPictureMode(new PictureInPictureParams.Builder()
                    .SetAspectRatio(AspectRatio)!
                    .Build()!);
            }
            else if (Build.VERSION.SdkInt >= BuildVersionCodes.N)
            {
                Platform.CurrentActivity.EnterPictureInPictureMode();
            }
        }
        catch
        {
            // Ignore
        }
    }

    public void OnPiPChanged(bool isInPictureInPictureMode)
    {
        playerView.UseController = !isInPictureInPictureMode;

        if (isInPictureInPictureMode)
        {
            Platform.CurrentActivity.RequestedOrientation = ScreenOrientation.Unspecified;
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
#pragma warning restore CS0618, CS0672, CA1422
}