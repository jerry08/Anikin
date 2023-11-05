﻿using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AniStream.Utils;
using AniStream.ViewModels.Framework;
using AniStream.Views;
using AniStream.Views.BottomSheets;
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

namespace AniStream.ViewModels;

public partial class VideoSourceViewModel : CollectionViewModel<ListGroup<VideoSource>>
{
    private readonly Media _media;

    private readonly IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();
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

        //var list = new List<VideoSource>();
        //list.Add(new VideoSource()
        //{
        //    Title = "test",
        //    Resolution = ""
        //});
        //
        //list.AddRange(list);
        //list.AddRange(list);
        //list.AddRange(list);
        //list.AddRange(list);
        //
        //Push(list);

        Load();
    }

    protected override async Task LoadCore()
    {
        //IsBusy = false;
        //return;

        IsBusy = true;
        IsLoading = true;

        try
        {
            var servers = await _provider.GetVideoServersAsync(_episode.Id, CancellationToken);

            foreach (var server in servers)
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

    private async Task<List<VideoSource>> GetVideos(VideoServer videoServer)
    {
        var videos = await _provider.GetVideosAsync(videoServer);

        return videos;
    }

    [RelayCommand]
    private async Task ItemClick(VideoSource video)
    {
        await VideoSourceSheet.DismissAsync();

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
            .Make($"Copied to clipboard:{Environment.NewLine}{url}", ToastDuration.Short, 17)
            .Show();

#if ANDROID
        var videoUri = Android.Net.Uri.Parse(url);

        var intent = new Android.Content.Intent(Android.Content.Intent.ActionView);
        intent.SetDataAndType(videoUri, "video/*");
        intent.SetFlags(Android.Content.ActivityFlags.NewTask);

        //_activity.CopyToClipboard(url, false);
        //_activity.ShowToast($"Copied \"{url}\"");

        var i = Android.Content.Intent.CreateChooser(intent, "Open Video in :")!;
        i.SetFlags(Android.Content.ActivityFlags.NewTask);

        Platform.CurrentActivity?.StartActivity(i);
#endif
    }

    public void Cancel() => _cancellationTokenSource.Cancel();
}
