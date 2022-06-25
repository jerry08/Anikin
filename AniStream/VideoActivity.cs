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

namespace AniStream
{
    [Activity(Label = "VideoActivity", ScreenOrientation = ScreenOrientation.Landscape, 
        ResizeableActivity = true, LaunchMode = LaunchMode.SingleTask, SupportsPictureInPicture = true,
        ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.SmallestScreenSize | ConfigChanges.ScreenLayout)]
    public class VideoActivity : AppCompatActivity, IPlayerEventListener, 
        IDialogInterfaceOnClickListener, IMediaSourceEventListener, 
        INetworkStateReceiverListener
    {
        NetworkStateReceiver NetworkStateReceiver;

        ProgressBar progressBar;
        SimpleExoPlayer player;
        string vidStreamUrl;
        int currentQuality;
        List<string> Qualities = new List<string>();
        private PlayerView playerView;
        LinearLayout controls;
        TextView title;
        TextView errorText;
        ImageButton nextEpisodeButton;
        ImageButton previousEpisodeButton;
        ImageButton qualityChangerButton;
        View mBottomLayout;
        View mVideoLayout;

        private int mSeekPosition;
        private int cachedHeight;
        private bool isFullscreen;
        Android.Net.Uri videoUri;

        Anime anime;
        Episode episode;
        private readonly AnimeClient _client = new AnimeClient();

        protected override void OnCreate(Bundle savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            
            SetContentView(Resource.Layout.videoviewer);
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

            NetworkStateReceiver = new NetworkStateReceiver();
            NetworkStateReceiver.AddListener(this);
            RegisterReceiver(NetworkStateReceiver, new IntentFilter(Android.Net.ConnectivityManager.ConnectivityAction));

            playerView = FindViewById<PlayerView>(Resource.Id.exoplayer);
            controls = FindViewById<LinearLayout>(Resource.Id.wholecontroller);
            progressBar = FindViewById<ProgressBar>(Resource.Id.buffer);
            title = FindViewById<TextView>(Resource.Id.titleofanime);
            qualityChangerButton = FindViewById<ImageButton>(Resource.Id.qualitychanger);
            nextEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_nextvideo);
            previousEpisodeButton = FindViewById<ImageButton>(Resource.Id.exo_prevvideo);
            errorText = FindViewById<TextView>(Resource.Id.errorText);

            nextEpisodeButton.Visibility = ViewStates.Gone;
            previousEpisodeButton.Visibility = ViewStates.Gone;

            title.Text = episode.EpisodeName;

            player = new SimpleExoPlayer.Builder(this).Build();
            playerView.Player = player;
            player.AddListener(this);

            progressBar.Visibility = ViewStates.Visible;

            _client.OnQualitiesLoaded += (s, e) =>
            {
                if (_client == null)
                    return;

                if (_client.Qualities.Count <= 0)
                {
                    errorText.Text = "Video not found.";
                    errorText.Visibility = ViewStates.Visible;
                
                    return;
                }

                errorText.Visibility = ViewStates.Gone;

                for (int i = 0; i < _client.Qualities.Count; i++)
                {
                    Qualities.Add(_client.Qualities[i].QualityUrl);
                }

                var quality = _client.Qualities.FirstOrDefault();

                currentQuality = 0;

                PlayVideo(quality.QualityUrl);
            };

            _client.GetEpisodeLinks(episode);

            qualityChangerButton.Click += (s, e) =>
            {
                var builder = 
                    new AlertDialog.Builder(this, Android.App.AlertDialog.ThemeDeviceDefaultLight);
                builder.SetTitle("Quality");
                builder.SetItems(_client.Qualities.Select(x => x.Resolution).ToArray(), this);
                builder.Show();
            };
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
                _client.CancelGetEpisodeLinks();
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

        public void OnClick(IDialogInterface dialog, int which)
        {
            if (currentQuality != which)
            {
                long t = player.CurrentPosition;
                currentQuality = which;
                player.SeekTo(t);

                PlayVideo(_client.Qualities[currentQuality].QualityUrl);
            }
        }

        void PlayVideo(string episodeLink)
        {
            videoUri = Android.Net.Uri.Parse(episodeLink.Replace(" ", "%20"));

            string userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36";

            DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter
                .Builder(this).Build();

            var dataSourceFactory = new DefaultHttpDataSourceFactory(userAgent, bandwidthMeter);

            for (int i = 0; i < _client.Qualities[currentQuality].Headers.Count; i++)
            {
                string headerKey = _client.Qualities[currentQuality].Headers.GetKey(i);
                string headerValue = _client.Qualities[currentQuality].Headers[i];

                dataSourceFactory.DefaultRequestProperties.Set(headerKey, headerValue);
            }

            IMediaSource mediaSource;
            var cacheDataSourceFactory = new CacheDataSourceFactory(this, 100 * 1024 * 1024,
                10 * 1024 * 1024, dataSourceFactory);

            var test = Util.InferContentType(videoUri);
            switch (test)
            {
                //case C.TypeDash:
                //    break;
                //case C.TypeSs:
                //    break;
                case C.TypeHls:
                    mediaSource = new HlsMediaSource.Factory(cacheDataSourceFactory)
                        .CreateMediaSource(videoUri);
                    break;
                //case C.TypeOther:
                //    break;
                default:
                    mediaSource = new ProgressiveMediaSource.Factory(cacheDataSourceFactory)
                        .CreateMediaSource(videoUri);
                    break;
            }

            player.Prepare(mediaSource);
            player.PlayWhenReady = true;

            anime.LastWatchedEp = episode.EpisodeNumber;

            //WeebUtils.SaveLastWatchedEp(this, anime);
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

        public void OnIsPlayingChanged(bool isPlaying)
        {

        }

        public void OnLoadingChanged(bool isLoading)
        {

        }

        public void OnPlaybackParametersChanged(PlaybackParameters playbackParameters)
        {

        }

        public void OnPlaybackSuppressionReasonChanged(int playbackSuppressionReason)
        {

        }

        public void OnPlayerError(ExoPlaybackException error)
        {
            errorText.Text = "Video not found.";
            errorText.Visibility = ViewStates.Visible;
        }

        public void OnPositionDiscontinuity(int reason)
        {

        }

        public void OnRepeatModeChanged(int repeatMode)
        {

        }

        public void OnSeekProcessed()
        {

        }

        public void OnShuffleModeEnabledChanged(bool shuffleModeEnabled)
        {

        }

        public void OnTimelineChanged(Timeline timeline, int reason)
        {

        }

        public void OnTracksChanged(TrackGroupArray trackGroups, TrackSelectionArray trackSelections)
        {

        }

        public void OnPlayerStateChanged(bool playWhenReady, int playbackState)
        {
            if (playbackState == Player.StateEnded)
            {
                //if (nextVideoLink == null || nextVideoLink.equals(""))
                //    Toast.makeText(getApplicationContext(), "Last Episode", Toast.LENGTH_SHORT).show();
                //else
                //{
                //    executeQuery(animeName, episodeNumber, nextVideoLink, imageLink);
                //    player.stop();
                //    currentScraper = 2;
                //    new ScrapeVideoLink(nextVideoLink, context).execute();
                //
                //}
            }
            else if (playbackState == Player.StateBuffering)
            {
                progressBar.Visibility = ViewStates.Visible;
            }
            else
            {
                progressBar.Visibility = ViewStates.Invisible;
            }
        }

        public void OnBufferingEnd(MediaPlayer mediaPlayer)
        {

        }

        public void OnBufferingStart(MediaPlayer mediaPlayer)
        {

        }

        public void OnPause(MediaPlayer mediaPlayer)
        {

        }

        public void OnScaleChange(bool isFullscreen)
        {
            this.isFullscreen = isFullscreen;
            if (isFullscreen)
            {
                ViewGroup.LayoutParams layoutParams = mVideoLayout.LayoutParameters;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = ViewGroup.LayoutParams.MatchParent;
                mVideoLayout.LayoutParameters = layoutParams;
                //GONE the unconcerned views to leave room for video and controller
                //mBottomLayout.Visibility = ViewStates.Gone;
            }
            else
            {
                ViewGroup.LayoutParams layoutParams = mVideoLayout.LayoutParameters;
                layoutParams.Width = ViewGroup.LayoutParams.MatchParent;
                layoutParams.Height = this.cachedHeight;
                mVideoLayout.LayoutParameters = layoutParams;
                //mBottomLayout.Visibility = ViewStates.Visible;
            }
        }

        public void OnStart(MediaPlayer mediaPlayer)
        {

        }

        #region IMediaSourceEventListener
        public void OnDownstreamFormatChanged(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerMediaLoadData mediaLoadData)
        {

        }
        public void OnLoadCanceled(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerLoadEventInfo loadEventInfo, MediaSourceEventListenerMediaLoadData mediaLoadData)
        {

        }
        public void OnLoadCompleted(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerLoadEventInfo loadEventInfo, MediaSourceEventListenerMediaLoadData mediaLoadData)
        {

        }
        public void OnLoadError(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerLoadEventInfo loadEventInfo, MediaSourceEventListenerMediaLoadData mediaLoadData, IOException error, bool wasCanceled)
        {

        }
        public void OnLoadStarted(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerLoadEventInfo loadEventInfo, MediaSourceEventListenerMediaLoadData mediaLoadData)
        {

        }
        public void OnMediaPeriodCreated(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId)
        {

        }
        public void OnMediaPeriodReleased(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId)
        {

        }
        public void OnReadingStarted(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId)
        {

        }
        public void OnUpstreamDiscarded(int windowIndex, MediaSourceMediaPeriodId mediaPeriodId, MediaSourceEventListenerMediaLoadData mediaLoadData)
        {

        }
        #endregion

        public void NetworkAvailable()
        {
            
        }

        public void NetworkUnavailable()
        {
            
        }
    }
}