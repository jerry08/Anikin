using System.Threading.Tasks;
using Anikin.Models;
using Anikin.Services;
using Anikin.ViewModels.Framework;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Anikin.ViewModels.Home;

public partial class HomeViewModel : BaseViewModel
{
    private readonly SettingsService _settingsService;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(SelectedTab))]
    int _selectedTabIndex;

    public HomeTabs SelectedTab => (HomeTabs)SelectedTabIndex;

    [ObservableProperty]
    ProfileViewModel _profileViewModel;

    [ObservableProperty]
    AnimeHomeViewModel _animeHomeViewModel;

    [ObservableProperty]
    MangaHomeViewModel _mangaHomeViewModel;

    public HomeViewModel(
        AnimeHomeViewModel animeHomeViewModel,
        MangaHomeViewModel mangaHomeViewModel,
        ProfileViewModel profileViewModel,
        SettingsService settingsService
    )
    {
        AnimeHomeViewModel = animeHomeViewModel;
        MangaHomeViewModel = mangaHomeViewModel;
        ProfileViewModel = profileViewModel;
        _settingsService = settingsService;
        _settingsService.Load();
    }

    async partial void OnSelectedTabIndexChanged(int value)
    {
        switch (SelectedTab)
        {
            case HomeTabs.Anime:
                if (!AnimeHomeViewModel.IsInitialized)
                    await AnimeHomeViewModel.Load();
                break;

            case HomeTabs.Profile:
                break;

            case HomeTabs.Manga:
                if (!MangaHomeViewModel.IsInitialized)
                    await MangaHomeViewModel.Load();
                break;
        }
    }

    protected override async Task LoadCore()
    {
        if (!await IsOnline())
            return;

        switch (SelectedTab)
        {
            case HomeTabs.Anime:
                if (!AnimeHomeViewModel.IsInitialized)
                    await AnimeHomeViewModel.Load();
                break;

            case HomeTabs.Profile:
                break;

            case HomeTabs.Manga:
                if (!MangaHomeViewModel.IsInitialized)
                    await MangaHomeViewModel.Load();
                break;
        }
    }

    [RelayCommand]
    async Task Refresh()
    {
        if (IsBusy)
            return;

        if (!await IsOnline())
        {
            IsRefreshing = false;
            return;
        }

        if (!IsRefreshing)
            IsBusy = true;

        await LoadCore();
    }
}
