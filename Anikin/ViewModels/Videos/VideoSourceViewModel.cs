using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Anikin.Utils;
using Anikin.ViewModels.Framework;
using Anikin.Views;
using Anikin.Views.BottomSheets;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Juro.Core.Providers;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.ApplicationModel.DataTransfer;
using Microsoft.Maui.Controls;
using Media = Jita.AniList.Models.Media;

namespace Anikin.ViewModels;

public partial class VideoSourceViewModel : CollectionViewModel<ListGroup<VideoSource>>
{
    private readonly Media _media;

    private readonly IAnimeProvider? _provider = ProviderResolver.GetAnimeProvider();
    private readonly IAnimeInfo _anime;
    private readonly Episode _episode;

    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    private VideoSourceSheet VideoSourceSheet { get; set; }

    public VideoSourceViewModel(
        VideoSourceSheet episodeSelectionSheet,
        IAnimeInfo anime,
        Episode episode,
        Media media
    )
    {
        _anime = anime;
        _episode = episode;
        _media = media;

        VideoSourceSheet = episodeSelectionSheet;

        Load();
    }

    protected override async Task LoadCore()
    {
        if (_provider is null)
        {
            IsBusy = false;
            IsRefreshing = false;
            await Toast.Make("No providers installed").Show();
            return;
        }

        IsBusy = true;
        IsLoading = true;

        try
        {
            var servers = await _provider.GetVideoServersAsync(_episode.Id, CancellationToken);

            foreach (var server in servers)
            {
                try
                {
                    var videos = await _provider.GetVideosAsync(server, CancellationToken);
                    //Push(videos);

                    if (videos.Count == 0)
                        continue;

                    foreach (var video in videos)
                    {
                        video.Title ??= !string.IsNullOrEmpty(video.Title)
                            ? video.Title
                            : !string.IsNullOrEmpty(video.Resolution)
                                ? video.Resolution
                                : "Default Quality";
                    }

                    Entities.Add(new(server.Name, videos));
                }
                catch
                {
                    // Ignore
                }
            }
        }
        catch (Exception ex)
        {
            if (!CancellationToken.IsCancellationRequested)
            {
                await App.AlertService.ShowAlertAsync("Error", ex.ToString());
            }
        }
        finally
        {
            IsBusy = false;
            IsRefreshing = false;
            IsLoading = false;

            OnPropertyChanged(nameof(Entities));
        }
    }

    [RelayCommand]
    private async Task ItemClick(VideoSource video)
    {
        await VideoSourceSheet.DismissAsync();

        if (Shell.Current.CurrentPage?.BindingContext is VideoPlayerViewModel videoPlayerViewModel)
        {
            videoPlayerViewModel.Video = video;
            videoPlayerViewModel.UpdateSource();
            return;
        }

        var page = new VideoPlayerView
        {
            BindingContext = new VideoPlayerViewModel(_anime, _episode, video, _media)
        };

        await Shell.Current.Navigation.PushAsync(page);
    }

    [RelayCommand]
    private async Task ItemLongClick(VideoSource video)
    {
        var url = video.VideoUrl.Replace(" ", "%20");

        await Clipboard.Default.SetTextAsync(url);

        await Toast
            .Make($"Copied to clipboard:{Environment.NewLine}{url}", ToastDuration.Short, 16)
            .Show();

#if ANDROID
        var videoUri = Android.Net.Uri.Parse(url);

        var intent = new Android.Content.Intent(Android.Content.Intent.ActionView);
        intent.SetDataAndType(videoUri, "video/*");
        intent.SetFlags(Android.Content.ActivityFlags.NewTask);

        //_activity.CopyToClipboard(url, false);
        //_activity.ShowToast($"Copied \"{url}\"");

        var chooserIntent = Android.Content.Intent.CreateChooser(intent, "Open Video in :")!;
        chooserIntent.SetFlags(Android.Content.ActivityFlags.NewTask);

        Platform.CurrentActivity?.StartActivity(chooserIntent);
#endif
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
