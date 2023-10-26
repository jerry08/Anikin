using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AniStream.Utils;
using AniStream.ViewModels.Framework;
using AniStream.Views;
using AniStream.Views.BottomSheets;
using CommunityToolkit.Mvvm.Input;
using Juro.Core.Models.Anime;
using Juro.Core.Models.Videos;
using Juro.Core.Providers;
using Microsoft.Maui.Controls;
using TaskExecutor;
using Media = Jita.AniList.Models.Media;

namespace AniStream.ViewModels;

public partial class VideoSourceViewModel : CollectionViewModel<ListGroup<VideoSource>>
{
    private readonly Media _media;

    private readonly IAnimeProvider _provider = ProviderResolver.GetAnimeProvider();
    private readonly IAnimeInfo _anime;
    private readonly Episode _episode;

    private EpisodeSelectionSheet EpisodeSelectionSheet { get; set; }

    public VideoSourceViewModel(
        EpisodeSelectionSheet episodeSelectionSheet,
        IAnimeInfo anime,
        Episode episode,
        Media media
    )
    {
        _anime = anime;
        _episode = episode;
        _media = media;

        EpisodeSelectionSheet = episodeSelectionSheet;

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

        var servers = await _provider.GetVideoServersAsync(_episode.Id);

        foreach (var server in servers)
        {
            var videos = await _provider.GetVideosAsync(server);
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

        IsBusy = false;
        IsRefreshing = false;
        IsLoading = false;

        OnPropertyChanged(nameof(Entities));

        return;

        var functions = Enumerable
            .Range(0, servers.Count)
            .Select(i => (Func<Task<List<VideoSource>>>)(async () => await GetVideos(servers[i])));

        var results = await TaskEx.Run(functions, 10);

        var list = results.SelectMany(x => x).ToList();
        //list.AddRange(list);
        //list.AddRange(list);

        for (var i = 0; i < 30; i++)
        {
            list.Add(new VideoSource() { Title = $"Test {i + 1}", });
        }

        for (var i = 0; i < list.Count; i++)
        {
            list[i].Title += $" {i + 1}";
        }

        //Push(list);

        EpisodeSelectionSheet.Detents[1].IsDefault = true;
        EpisodeSelectionSheet.SelectedDetent = EpisodeSelectionSheet.Detents[1];
        //EpisodeSelectionSheet.SelectedDetent = EpisodeSelectionSheet.Detents[1];
        //EpisodeSelectionSheet.SetHeights();
        //EpisodeSelectionSheet.Test();
        //EpisodeSelectionSheet.ForceLayout();
        return;

        await EpisodeSelectionSheet.DismissAsync(false);

        EpisodeSelectionSheet = new() { BindingContext = this };

        EpisodeSelectionSheet.Detents[0].IsDefault = true;

        //EpisodeSelectionSheet.Showing += (s, e) =>
        //{
        //    EpisodeSelectionSheet.Controller.Behavior.DisableShapeAnimations();
        //};

        await EpisodeSelectionSheet.ShowAsync(false);
    }

    private async Task<List<VideoSource>> GetVideos(VideoServer videoServer)
    {
        var videos = await _provider.GetVideosAsync(videoServer);

        return videos;
    }

    [RelayCommand]
    private async Task ItemClick(VideoSource video)
    {
        await EpisodeSelectionSheet.DismissAsync();

        var page1 = new VideoPlayerView();
        page1.BindingContext = new VideoPlayerViewModel(_anime, _episode, video, _media);

        await Shell.Current.Navigation.PushAsync(page1);
    }

    public void Cancel() { }
}
