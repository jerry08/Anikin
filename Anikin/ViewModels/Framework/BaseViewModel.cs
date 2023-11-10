using System.Collections.Generic;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Networking;
using Plugin.ContextMenuContainer;

namespace Anikin.ViewModels.Framework;

public partial class BaseViewModel : ObservableObject
{
    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private bool _isRefreshing;

    [ObservableProperty]
    private string? _title;

    [ObservableProperty]
    private string? _subtitle;

    [ObservableProperty]
    private bool _isInitialized;

    [ObservableProperty]
    private string? _profilePicPath;

    [RelayCommand]
    public async Task Load()
    {
        IsInitialized = true;

        // Apply delay for smooth loading, e.g. when logging out and logging back in
        // navigating to the dashboard will be smooth when loading data
        await Task.Delay(1);

        await LoadCore();
    }

    protected virtual Task LoadCore() => default!;

    public virtual void OnNavigated() { }

    public virtual void OnAppearing() { }

    public virtual void OnDisappearing() { }

    [RelayCommand]
    void ShowContextMenu(ContextMenuContainer menu)
    {
        menu.Show();
    }

    public async Task<bool> IsOnline(bool showAlert = true)
    {
        var isOnline = Connectivity.Current.NetworkAccess == NetworkAccess.Internet;
        if (!isOnline)
        {
            IsBusy = false;
            IsRefreshing = false;

            if (showAlert)
                await ShowNoInternetAlert();
        }

        return isOnline;
    }

    private Task ShowNoInternetAlert()
    {
        return App.AlertService.ShowAlertAsync(
            "No Internet Connection.",
            "If the problem persists, please try again later.",
            "CLOSE"
        );
    }

    [RelayCommand]
    public async Task GoBack(Dictionary<string, object>? parameters = null)
    {
        if (parameters is null)
            await Shell.Current.Navigation.PopAsync();
        else
            await Shell.Current.GoToAsync("..", parameters);
    }
}
