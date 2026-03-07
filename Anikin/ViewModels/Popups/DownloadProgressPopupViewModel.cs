using System;
using System.Threading;
using System.Threading.Tasks;
using Anikin.ViewModels.Framework;
using Anikin.Views.Popups;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Anikin.ViewModels.Popups;

public partial class DownloadProgressPopupViewModel : BaseViewModel, IProgress<double>
{
    private readonly CancellationTokenSource _cancellationTokenSource;

    [ObservableProperty]
    private string _title = "";

    [ObservableProperty]
    private double _progress;

    [ObservableProperty]
    private string _progressText = "0%";

    public event CloseHandler<bool>? OnClose;

    public CancellationToken CancellationToken => _cancellationTokenSource.Token;

    public DownloadProgressPopupViewModel(
        string title,
        CancellationTokenSource cancellationTokenSource
    )
    {
        Title = title;
        _cancellationTokenSource = cancellationTokenSource;
    }

    public void Report(double value)
    {
        Progress = value;
        ProgressText = $"{(int)(value * 100)}%";
    }

    public async Task CompleteAsync()
    {
        Progress = 1;
        ProgressText = "100%";
        await ClosePopupAsync(true);
    }

    public async Task FailAsync(string? error = null)
    {
        ProgressText = error ?? "Failed";
        await Task.Delay(100);
        await ClosePopupAsync(false);
    }

    [RelayCommand]
    async Task Cancel()
    {
        _cancellationTokenSource.Cancel();
        await ClosePopupAsync(false);
    }

    private async Task ClosePopupAsync(bool result)
    {
        if (OnClose is not null)
        {
            await OnClose.Invoke(result);
            OnClose = null;
        }
    }
}
