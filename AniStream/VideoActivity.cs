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

namespace AniStream
{
    //[Activity(Label = "VideoActivity", ScreenOrientation = ScreenOrientation.Landscape,
    [Activity(Label = "VideoActivity", ScreenOrientation = ScreenOrientation.Landscape | ScreenOrientation.Portrait,
        ResizeableActivity = true, LaunchMode = LaunchMode.SingleTask, SupportsPictureInPicture = true,
        //ResizeableActivity = true, NoHistory = true, LaunchMode = LaunchMode.Multiple, SupportsPictureInPicture = true, Exported = true,
        ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.SmallestScreenSize | ConfigChanges.ScreenLayout | ConfigChanges.Keyboard | ConfigChanges.KeyboardHidden)]
    public class VideoActivity : AppCompatActivity, IPlayer.IListener,
        //IDialogInterfaceOnClickListener, IMediaSourceEventListener, 
        INetworkStateReceiverListener
    {
        private readonly AnimeClient _client = new AnimeClient(WeebUtils.AnimeSite);

        private Anime anime;
        private Episode episode;
        private Video video;

        private NetworkStateReceiver NetworkStateReceiver;

        private ProgressBar progressBar;
        private IExoPlayer player;
        private ImageButton exoplay;
        //private int currentVideoIndex;
        private List<string> Qualities = new List<string>();
        //private StyledPlayerView playerView;
        private PlayerView playerView;
        private LinearLayout controls;
        private TextView title;
        private TextView errorText;
        private ImageButton nextEpisodeButton;
        private ImageButton previousEpisodeButton;
        private ImageButton videoChangerButton;
        private View mVideoLayout;

        private int cachedHeight;
        private bool isFullscreen;
        private Android.Net.Uri videoUri;

        SelectorDialogFragment selector;

        protected async override void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);

            SetContentView(Resource.Layout.videoviewer);
            AndroidEnvironment.UnhandledExceptionRaiser += (s, e) =>
            {

            };
            
            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
            {

            };

            TaskScheduler.UnobservedTaskException += (s, e) =>
            {

            };

            //SetVideoOptions();

            if (Build.VERSION.SdkInt >= BuildVersionCodes.Gingerbread)
            {
                RequestedOrientation = ScreenOrientation.SensorLandscape;
            }

            string animeString = Intent.GetStringExtra("anime");
            if (!string.IsNullOrEmpty(animeString))
            {
                anime = JsonConvert.DeserializeObject<Anime>(animeString);
            }

            string episodeString = Intent.GetStringExtra("episode");
            if (!string.IsNullOrEmpty(episodeString))
            {
                episode = JsonConvert.DeserializeObject<Episode>(episodeString);
            }
            
            string videoString = Intent.GetStringExtra("video");
            if (!string.IsNullOrEmpty(videoString))
            {
                video = JsonConvert.DeserializeObject<Video>(videoString);
            }

            var bookmarkManager = new BookmarkManager("recently_watched");
            var isBooked = await bookmarkManager.IsBookmarked(anime);
            if (isBooked)
            {
                bookmarkManager.RemoveBookmark(anime);
            }

            bookmarkManager.SaveBookmark(anime, true);

            NetworkStateReceiver = new NetworkStateReceiver();
            NetworkStateReceiver.AddListener(this);
            RegisterReceiver(NetworkStateReceiver, new IntentFilter(Android.Net.ConnectivityManager.ConnectivityAction));

            playerView = FindViewById<PlayerView>(Resource.Id.exoplayer);
            controls = FindViewById<LinearLayout>(Resource.Id.wholecontroller);
            exoplay = FindViewById<ImageButton>(Resource.Id.exo_play);
            progressBar = FindViewById<ProgressBar>(Resource.Id.buffer);
            title = FindViewById<TextView>(Resource.Id.titleofanime);
            videoChangerButton = FindViewById<ImageButton>(Resource.Id.qualitychanger);
            nextEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_nextvideo);
            previousEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_prevvideo);
            errorText = FindViewById<TextView>(Resource.Id.errorText);

            nextEpisodeButton.Visibility = ViewStates.Gone;
            previousEpisodeButton.Visibility = ViewStates.Gone;

            title.Text = episode.Name;

            player = new IExoPlayer.Builder(this).Build();
            playerView.Player = player;
            player.AddListener(this);

            progressBar.Visibility = ViewStates.Visible;

            //exoplay.Click += (s, e) =>
            //{
            //    if (player.IsPlaying)
            //    {
            //        Picasso.Get().Load(Resource.Drawable.anim_play_to_pause)
            //            .Into(exoplay);
            //        player.Pause();
            //    }
            //    else
            //    {
            //        Picasso.Get().Load(Resource.Drawable.anim_pause_to_play)
            //            .Into(exoplay);
            //        player.Play();
            //    }
            //};

            PlayVideo(video);

            videoChangerButton.Click += (s, e) =>
            {
                //var gs = player.PlayerError;
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

        private long lastCurrentPosition = 0;

        public void OnClick(IDialogInterface dialog, int which)
        {
            /*if (currentVideoIndex != which)
            {
                currentVideoIndex = which;
                lastCurrentPosition = player.CurrentPosition;

                PlayVideo(_client.Videos[currentVideoIndex].VideoUrl);
                player.SeekTo(lastCurrentPosition);

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
                player.Stop();
                player.Release();
                _client.CancelGetVideos();

                base.OnBackPressed();
            });

            alert.SetNegativeButton("Cancel", (s, e) =>
            {

            });

            alert.SetCancelable(false);
            var dialog = alert.Create();
            dialog.Show();
        }

        public override void OnTrimMemory([GeneratedEnum] TrimMemory level)
        {
            base.OnTrimMemory(level);
        }

        protected override void OnPause()
        {
            base.OnPause();

            player.PlayWhenReady = false;
        }

        /*private void PlayVideo(Video video)
        {
            videoUri = Android.Net.Uri.Parse(video.VideoUrl.Replace(" ", "%20"));

            string userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36";

            DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter
                .Builder(this).Build();

            var dataSourceFactory = new DefaultHttpDataSourceFactory(userAgent, bandwidthMeter);

            for (int i = 0; i < video.Headers.Count; i++)
            {
                string headerKey = video.Headers.GetKey(i);
                string headerValue = video.Headers[i];

                dataSourceFactory.DefaultRequestProperties.Set(headerKey, headerValue);
            }

            DefaultExtractorsFactory extractorsFactory =
                new DefaultExtractorsFactory().SetConstantBitrateSeekingEnabled(true);
            
            var cacheDataSourceFactory = new CacheDataSourceFactory(this, 100 * 1024 * 1024,
                10 * 1024 * 1024, dataSourceFactory);

            var type = Util.InferContentType(videoUri);
            IMediaSource mediaSource = type switch
            {
                //case C.TypeDash:
                //    break;
                //case C.TypeSs:
                //    break;
                C.TypeHls => new HlsMediaSource.Factory(cacheDataSourceFactory)
                    .CreateMediaSource(videoUri),
                //case C.TypeOther:
                //    break;
                _ => new ProgressiveMediaSource.Factory(cacheDataSourceFactory, extractorsFactory)
                    .CreateMediaSource(videoUri),
            };

            player.Prepare(mediaSource);
            player.PlayWhenReady = true;

            anime.LastWatchedEp = episode.Number;

            //WeebUtils.SaveLastWatchedEp(this, anime);
        }*/

        public void PlayVideo(Video video)
        {
            if (selector is not null)
            {
                selector.Dismiss();
                selector = null;
            }

            lastCurrentPosition = player.CurrentPosition;

            videoUri = Android.Net.Uri.Parse(video.VideoUrl.Replace(" ", "%20"));

            var userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36";

            var bandwidthMeter = new DefaultBandwidthMeter.Builder(this).Build();

            //var httpClient = new OkHttpClient.Builder()
            //    .FollowSslRedirects(true)
            //    .FollowRedirects(true)
            //    .Build();

            var dataSourceFactory = new DefaultHttpDataSource.Factory();
            //var dataSourceFactory = new OkHttpDataSource.Factory(httpClient);

            dataSourceFactory.SetUserAgent(userAgent);
            dataSourceFactory.SetTransferListener(bandwidthMeter);
            dataSourceFactory.SetDefaultRequestProperties(video.Headers.ToDictionary());

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
                .SetUri(videoUri)
                .SetMimeType(mimeType)
                .Build();

            var type = Util.InferContentType(videoUri);
            IMediaSource mediaSource = type switch
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

            player.SetMediaSource(mediaSource);

            //player.SetMediaItem(mediaItem);

            //player.Prepare(mediaSource);
            player.Prepare();
            player.PlayWhenReady = true;

            anime.LastWatchedEp = episode.Number;

            //WeebUtils.SaveLastWatchedEp(this, anime);

            player.SeekTo(lastCurrentPosition);

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
            if (playbackState == IPlayer.StateReady)
            {
                progressBar.Visibility = ViewStates.Invisible;

                //if (lastCurrentPosition > 0)
                //{
                //    player.SeekTo(lastCurrentPosition);
                //    lastCurrentPosition = 0;
                //}
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
            {
                HideSystemUI();
            }
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
                var layoutParams = mVideoLayout.LayoutParameters;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = ViewGroup.LayoutParams.MatchParent;
                mVideoLayout.LayoutParameters = layoutParams;
            }
            else
            {
                var layoutParams = mVideoLayout.LayoutParameters;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = this.cachedHeight;
                mVideoLayout.LayoutParameters = layoutParams;
            }
        }

        public void OnIsPlayingChanged(bool isPlaying)
        {

        }

        public void OnLoadingChanged(bool isLoading)
        {

        }

        public void OnPlaybackParametersChanged(PlaybackParameters playbackParameters)
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

            Toast.MakeText(this, error?.Message, ToastLength.Short).Show();
        }

        public void NetworkAvailable()
        {
            
        }

        public void NetworkUnavailable()
        {
            
        }
    }
}