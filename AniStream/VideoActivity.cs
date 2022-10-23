using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Media;
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
using Java.IO;
using Newtonsoft.Json;
using AniStream.Utils;
using AnimeDl;
using AniStream.BroadcastReceivers;
using AndroidX.AppCompat.App;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;
using AnimeDl.Models;
using AniStream.Fragments;
using AnimeDl.Utils.Extensions;
using Square.Picasso;
using Com.Google.Android.Exoplayer2.Upstream.Cache;
using static Com.Google.Android.Exoplayer2.IPlayer;
using AnimeDl.Anilist.Api;
using Square.OkHttp3;
using AndroidX.Fragment.App;
using System.Threading.Tasks;
using Com.Google.Android.Exoplayer2.Video;
using Google.Android.Material.BottomSheet;
using AnimeDl.Utils;
using Com.Google.Android.Exoplayer2.Ext.Okhttp;
using Android.Graphics.Drawables;
using static Android.Icu.Text.Transliterator;
using Bumptech.Glide;
using AndroidX.CardView.Widget;
using AniStream.Models;
using Google.Android.Material.Card;
using Java.Nio.Channels;

namespace AniStream
{
    //[Activity(Label = "VideoActivity", ScreenOrientation = ScreenOrientation.Landscape,
    [Activity(Label = "VideoActivity", Theme = "@style/VideoPlayerTheme",
        ResizeableActivity = true, LaunchMode = LaunchMode.SingleTask, SupportsPictureInPicture = true,
        //ResizeableActivity = true, NoHistory = true, LaunchMode = LaunchMode.Multiple, SupportsPictureInPicture = true, Exported = true,
        ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.SmallestScreenSize | ConfigChanges.ScreenLayout | ConfigChanges.Keyboard | ConfigChanges.KeyboardHidden)]
    public class VideoActivity : AppCompatActivity, IPlayer.IListener,
        //IDialogInterfaceOnClickListener, IMediaSourceEventListener, 
        INetworkStateReceiverListener, ITrackNameProvider
    {
        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);

        private readonly PlayerSettings _playerSettings = new();
        
        private Anime anime = default!;
        private Episode episode = default!;
        private Video video = default!;

        private NetworkStateReceiver NetworkStateReceiver = default!;

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
        private TextView errorText = default!;
        private ImageButton nextEpisodeButton = default!;
        private ImageButton previousEpisodeButton = default!;
        private ImageButton videoChangerButton = default!;
        private View mVideoLayout = default!;

        private int cachedHeight;
        private bool isFullscreen;
        private Android.Net.Uri videoUri = default!;

        private SelectorDialogFragment? selector;

        private bool IsBuffering { get; set; } = true;

        protected async override void OnCreate(Bundle? savedInstanceState)
        {
            base.OnCreate(savedInstanceState);

            SetContentView(Resource.Layout.activity_exoplayer);

            AndroidEnvironment.UnhandledExceptionRaiser += (s, e) =>
            {

            };
            
            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
            {

            };

            TaskScheduler.UnobservedTaskException += (s, e) =>
            {

            };

            _playerSettings.Load();

            //SetVideoOptions();

            if (_playerSettings.AlwaysInLandscapeMode)
            {
                if (Build.VERSION.SdkInt >= BuildVersionCodes.Gingerbread)
                {
                    RequestedOrientation = ScreenOrientation.SensorLandscape;
                }
            }

            var animeString = Intent!.GetStringExtra("anime");
            if (!string.IsNullOrEmpty(animeString))
                anime = JsonConvert.DeserializeObject<Anime>(animeString)!;

            var episodeString = Intent.GetStringExtra("episode");
            if (!string.IsNullOrEmpty(episodeString))
                episode = JsonConvert.DeserializeObject<Episode>(episodeString)!;

            var bookmarkManager = new BookmarkManager("recently_watched");

            var isBooked = await bookmarkManager.IsBookmarked(anime);
            if (isBooked)
                bookmarkManager.RemoveBookmark(anime);
            
            bookmarkManager.SaveBookmark(anime, true);

            NetworkStateReceiver = new NetworkStateReceiver();
            NetworkStateReceiver.AddListener(this);
            RegisterReceiver(NetworkStateReceiver, new IntentFilter(Android.Net.ConnectivityManager.ConnectivityAction));

            animeTitle = FindViewById<TextView>(Resource.Id.exo_anime_title)!;
            episodeTitle = FindViewById<TextView>(Resource.Id.exo_ep_sel)!;

            playerView = FindViewById<StyledPlayerView>(Resource.Id.player_view)!;
            exoplay = FindViewById<ImageButton>(Resource.Id.exo_play)!;
            exoQuality = FindViewById<ImageButton>(Resource.Id.exo_quality)!;
            progressBar = FindViewById<ProgressBar>(Resource.Id.buffer)!;
            
            videoChangerButton = FindViewById<ImageButton>(Resource.Id.qualitychanger)!;
            nextEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_nextvideo)!;
            previousEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_prevvideo)!;
            errorText = FindViewById<TextView>(Resource.Id.errorText)!;

            var skipButton = FindViewById<MaterialCardView>(Resource.Id.exo_skip)!;

            var prevButton = FindViewById<ImageButton>(Resource.Id.exo_prev_ep)!;
            var nextButton = FindViewById<ImageButton>(Resource.Id.exo_next_ep)!;

            var settingsButton = FindViewById<ImageButton>(Resource.Id.exo_settings)!;
            var sourceButton = FindViewById<ImageButton>(Resource.Id.exo_source)!;
            var subButton = FindViewById<ImageButton>(Resource.Id.exo_sub)!;
            var downloadButton = FindViewById<ImageButton>(Resource.Id.exo_download)!;
            var pipButton = FindViewById<ImageButton>(Resource.Id.exo_pip)!;
            var playBackSpeedButton = FindViewById<ImageButton>(Resource.Id.exo_playback_speed)!;
            var screenButton = FindViewById<ImageButton>(Resource.Id.exo_screen)!;
            
            var backButton = FindViewById<ImageButton>(Resource.Id.exo_back)!;
            var lockButton = FindViewById<ImageButton>(Resource.Id.exo_lock)!;

            //TODO: Implement these
            prevButton.Visibility = ViewStates.Gone;
            nextButton.Visibility = ViewStates.Gone;

            settingsButton.Visibility = ViewStates.Gone;
            subButton.Visibility = ViewStates.Gone;
            pipButton.Visibility = ViewStates.Gone;
            playBackSpeedButton.Visibility = ViewStates.Gone;
            lockButton.Visibility = ViewStates.Gone;
            screenButton.Visibility = ViewStates.Gone;

            sourceButton.Click += (s, e) =>
            {
                selector = SelectorDialogFragment.NewInstance(anime, episode, this);
                selector.Show(SupportFragmentManager, "dialog");
            };

            backButton.Click += (s, e) =>
            {
                this.OnBackPressed();
            };

            skipButton.Click += (s, e) =>
            {
                exoPlayer.SeekTo(exoPlayer.CurrentPosition + 85000);
            };

            var fastForwardCont = FindViewById<CardView>(Resource.Id.exo_fast_forward_button_cont);
            var fastRewindCont = FindViewById<CardView>(Resource.Id.exo_fast_rewind_button_cont);
            var fastForwardButton = FindViewById<ImageButton>(Resource.Id.exo_fast_forward_button);
            var rewindButton = FindViewById<ImageButton>(Resource.Id.exo_fast_rewind_button);

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

            animeTitle.Text = anime.Title;
            episodeTitle.Text = episode.Name;

            var trackSelectionFactory = new AdaptiveTrackSelection.Factory();
            trackSelector = new DefaultTrackSelector(this, trackSelectionFactory);

            //var ff = trackSelector.BuildUponParameters();
            //ff.SetMinVideoSize(720, 480).SetMaxVideoSize(1, 1);
            //
            //trackSelector.SetParameters(ff);

            playerView.ControllerShowTimeoutMs = 5000;

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

            if (_playerSettings.SelectServerBeforePlaying)
            {
                var videoString = Intent.GetStringExtra("video");
                if (!string.IsNullOrEmpty(videoString))
                    video = JsonConvert.DeserializeObject<Video>(videoString)!;

                PlayVideo(video);
            }
            else
            {
                var progressBar = FindViewById<ProgressBar>(Resource.Id.exo_init_buffer);
                progressBar.Visibility = ViewStates.Visible;

                _client.OnVideosLoaded += (s, e) =>
                {
                    this.RunOnUiThread(() =>
                    {
                        if (e.Videos.Count > 0)
                        {
                            PlayVideo(e.Videos[0]);
                            progressBar.Visibility = ViewStates.Gone;
                        }
                        else
                        {
                            progressBar.Visibility = ViewStates.Gone;
                            Toast.MakeText(this, "Failed to play video", ToastLength.Short).Show();
                        }
                    });
                };

                _client.OnVideoServersLoaded += (s, e) =>
                {
                    this.RunOnUiThread(() =>
                    {
                        if (e.VideoServers.Count > 0)
                        {
                            _client.GetVideos(e.VideoServers[0]);
                        }
                        else
                        {
                            progressBar.Visibility = ViewStates.Gone;
                            Toast.MakeText(this, "Failed to find video", ToastLength.Short).Show();
                        }
                    });
                };

                _client.GetVideoServers(episode.Id);
            }

            return;

            playerView = FindViewById<StyledPlayerView>(Resource.Id.exoplayer)!;
            //controls = FindViewById<LinearLayout>(Resource.Id.wholecontroller)!;
            exoplay = FindViewById<ImageButton>(Resource.Id.exo_play)!;
            progressBar = FindViewById<ProgressBar>(Resource.Id.buffer)!;
            animeTitle = FindViewById<TextView>(Resource.Id.titleofanime)!;
            videoChangerButton = FindViewById<ImageButton>(Resource.Id.qualitychanger)!;
            nextEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_nextvideo)!;
            previousEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_prevvideo)!;
            errorText = FindViewById<TextView>(Resource.Id.errorText)!;

            nextEpisodeButton.Visibility = ViewStates.Gone;
            previousEpisodeButton.Visibility = ViewStates.Gone;

            animeTitle.Text = episode.Name;

            //var trackSelectionFactory = new AdaptiveTrackSelection.Factory();
            //trackSelector = new DefaultTrackSelector(this, trackSelectionFactory);
            //
            //exoPlayer = new IExoPlayer.Builder(this)
            //    .SetTrackSelector(trackSelector)!
            //    .Build()!;

            playerView.Player = exoPlayer;
            exoPlayer.AddListener(this);

            progressBar.Visibility = ViewStates.Visible;

            //exoplay.Click += (s, e) =>
            //{
            //    if (exoPlayer.IsPlaying)
            //    {
            //        Picasso.Get().Load(Resource.Drawable.anim_play_to_pause)
            //            .Into(exoplay);
            //        exoPlayer.Pause();
            //    }
            //    else
            //    {
            //        Picasso.Get().Load(Resource.Drawable.anim_pause_to_play)
            //            .Into(exoplay);
            //        exoPlayer.Play();
            //    }
            //};

            PlayVideo(video);

            videoChangerButton.Click += (s, e) =>
            {
                //var gs = exoPlayer.PlayerError;
                //return;

                //var res = _client.Videos.Select(x => x.Resolution).ToArray();
                //
                //var builder = new Android.App.AlertDialog.Builder(this,
                //    Android.App.AlertDialog.ThemeDeviceDefaultLight);
                //builder.SetTitle("Resolution");
                //builder.SetItems(res, this);
                //builder.Show();

                selector = SelectorDialogFragment.NewInstance(anime, episode, this);
                //var test = (selector.Dialog as BottomSheetDialog);
                //var behavior = BottomSheetBehavior.From(selector);
                //behavior.State = BottomSheetBehavior.StateExpanded;
                selector.Show(SupportFragmentManager, "dialog");
            };
        }

        public void InitPlayer()
        {

        }

        private long lastCurrentPosition = 0;

        public void OnClick(IDialogInterface dialog, int which)
        {
            /*if (currentVideoIndex != which)
            {
                currentVideoIndex = which;
                lastCurrentPosition = exoPlayer.CurrentPosition;

                PlayVideo(_client.Videos[currentVideoIndex].VideoUrl);
                exoPlayer.SeekTo(lastCurrentPosition);

                lastCurrentPosition = 0;
            }*/
        }

        protected override void OnDestroy()
        {
            base.OnDestroy();

            NetworkStateReceiver.RemoveListener(this);
            UnregisterReceiver(NetworkStateReceiver);
        }

        public override void OnBackPressed()
        {
            var alert = new AlertDialog.Builder(this);
            alert.SetMessage("Are you sure you want to go back?");
            alert.SetPositiveButton("Yes", (s, e) =>
            {
                exoPlayer.Stop();
                exoPlayer.Release();
                _client.CancelGetVideoServers();
                _client.CancelGetVideos();
                VideoCache.Release();

                base.OnBackPressed();
            });

            alert.SetNegativeButton("Cancel", (s, e) =>
            {

            });

            alert.SetCancelable(false);
            var dialog = alert.Create();
            dialog.Show();
        }

        // QUALITY SELECTOR
        private void ShowM3U8TrackSelector()
        {
            var mappedTrackInfo = trackSelector.CurrentMappedTrackInfo;

            //var trackSelectionDialogBuilder = new TrackSelectionDialogBuilder(this,
            //    new Java.Lang.String("Available Qualities"), exoPlayer, C.TrackTypeVideo);

            var trackSelectionDialogBuilder = new TrackSelectionDialogBuilder(this,
                new Java.Lang.String("Available Qualities"), exoPlayer, C.TrackTypeVideo);

            trackSelectionDialogBuilder.SetTheme(Resource.Style.DialogTheme);
            //trackSelectionDialogBuilder.SetTrackNameProvider(this);

            var trackDialog = trackSelectionDialogBuilder.Build()!;
            //trackDialog.DismissEvent += (s, e) =>
            //{
            //    HideSystemUI();
            //};

            trackDialog.Show();
        }

        protected override void OnPause()
        {
            base.OnPause();

            exoPlayer.PlayWhenReady = false;
        }

        public void PlayVideo(Video video)
        {
            if (selector is not null)
            {
                selector.Dismiss();
                selector = null;
            }

            //var test = await Http.Client.SendHttpRequestAsync(video.VideoUrl, video.Headers);

            lastCurrentPosition = exoPlayer.CurrentPosition;

            videoUri = Android.Net.Uri.Parse(video.VideoUrl.Replace(" ", "%20"))!;

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

            //anime.LastWatchedEp = episode.Number;

            //WeebUtils.SaveLastWatchedEp(this, anime);

            exoPlayer.SeekTo(lastCurrentPosition);

            lastCurrentPosition = 0;
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

            return;

            if (playbackState == IPlayer.StateReady)
            {
                progressBar.Visibility = ViewStates.Invisible;
                errorText.Visibility = ViewStates.Gone;
            }
            else if (playbackState == IPlayer.StateEnded)
            {
                //Play next video?
            }
            else if (playbackState == IPlayer.StateBuffering)
            {
                progressBar.Visibility = ViewStates.Visible;
            }
            else
            {
                progressBar.Visibility = ViewStates.Invisible;
                errorText.Visibility = ViewStates.Gone;
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

        void SetVideoOptions()
        {
            //View decorView = Window.DecorView;
            //SystemUiFlags uiOptions = SystemUiFlags.HideNavigation
            //        | SystemUiFlags.Fullscreen | SystemUiFlags.ImmersiveSticky;
            //decorView.WindowSystemUiVisibility = uiOptions;

            Window.DecorView.SystemUiVisibility = (StatusBarVisibility)SystemUiFlags.HideNavigation
                | (StatusBarVisibility)SystemUiFlags.Fullscreen
                | (StatusBarVisibility)SystemUiFlags.ImmersiveSticky;
        }

        private void HideSystemUI()
        {
            Window.DecorView.SystemUiVisibility = (StatusBarVisibility)SystemUiFlags.HideNavigation
                | (StatusBarVisibility)SystemUiFlags.Fullscreen
                | (StatusBarVisibility)SystemUiFlags.ImmersiveSticky;
        }

        private void ShowSystemUI()
        {
            Window.DecorView.SystemUiVisibility = (StatusBarVisibility)SystemUiFlags.LayoutStable
                | (StatusBarVisibility)SystemUiFlags.HideNavigation
                | (StatusBarVisibility)SystemUiFlags.LayoutFullscreen;
        }

        public override void OnWindowFocusChanged(bool hasFocus)
        {
            base.OnWindowFocusChanged(hasFocus);

            if (hasFocus)
                HideSystemUI();
        }

        public void OnPlayerError(PlaybackException? error)
        {
            errorText.Text = "Video not found.";
            errorText.Visibility = ViewStates.Visible;
        }

        public void OnScaleChange(bool isFullscreen)
        {
            this.isFullscreen = isFullscreen;
            if (isFullscreen)
            {
                var layoutParams = mVideoLayout.LayoutParameters!;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = ViewGroup.LayoutParams.MatchParent;
                mVideoLayout.LayoutParameters = layoutParams;
            }
            else
            {
                var layoutParams = mVideoLayout.LayoutParameters!;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = this.cachedHeight;
                mVideoLayout.LayoutParameters = layoutParams;
            }
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

        public void OnTracksChanged(TrackGroupArray trackGroups, TrackSelectionArray trackSelections)
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

        }

        public void OnPlayerErrorChanged(PlaybackException? error)
        {
            errorText.Text = "Video not found.";
            errorText.Visibility = ViewStates.Visible;

            if (error is not null && error.Message is not null)
                Toast.MakeText(this, error?.Message, ToastLength.Short)!.Show();
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
    }
}