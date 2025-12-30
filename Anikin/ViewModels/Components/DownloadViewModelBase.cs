using System;
using System.IO;
using System.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using Gress;

namespace Anikin.ViewModels.Components;

public partial class DownloadViewModelBase : ObservableObject, IDisposable
{
    //private readonly CancellationTokenSource _cancellationTokenSource = new();

    public string TempFilePath { get; set; } = default!;

    public string? FilePath { get; set; }

    public string? FileName => Path.GetFileName(FilePath);

    [ObservableProperty]
    private Percentage _percentageProgress;

    [ObservableProperty]
    private bool _isProgressIndeterminate = true;

    //public CancellationToken CancellationToken => _cancellationTokenSource.Token;
    public CancellationToken CancellationToken => CancellationTokenSource.Token;

    public CancellationTokenSource CancellationTokenSource { get; set; } = new();

    [ObservableProperty]
    private DownloadStatus _status = DownloadStatus.None;

    [ObservableProperty]
    private bool _isCanceledOrFailed;

    public string? ErrorMessage { get; set; }

    [ObservableProperty]
    private bool _canShowInitialContextMenu;

    [ObservableProperty]
    private bool _canShowDownloadingContextMenu;

    [ObservableProperty]
    private bool _canShowDownloadFailedContextMenu;

    [ObservableProperty]
    private bool _canCancel;

    public DownloadViewModelBase()
    {
        PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(CanCancel) || e.PropertyName == nameof(Status))
            {
                //CanShowInitialContextMenu = !CanCancel;
                CanShowInitialContextMenu =
                    Status
                        is DownloadStatus.None
                            or DownloadStatus.Canceled
                            or DownloadStatus.Completed;

                //CanShowDownloadingContextMenu = CanCancel;
                CanShowDownloadingContextMenu =
                    Status is DownloadStatus.Started or DownloadStatus.Enqueued;

                CanShowDownloadFailedContextMenu = Status is DownloadStatus.Failed;
            }
        };

        CanShowInitialContextMenu = true;
    }

    public void BeginDownload()
    {
        PercentageProgress = Percentage.FromValue(0);
        CancellationTokenSource = new();
        IsProgressIndeterminate = true;
        Status = DownloadStatus.Enqueued;
        CanCancel = true;
    }

    public void EndDownload()
    {
        CanCancel = false;
        IsProgressIndeterminate = false;
    }

    public void Cancel()
    {
        if (!CanCancel)
            return;

        //_cancellationTokenSource.Cancel();
        CancellationTokenSource.Cancel();
    }

    //public void Dispose() => _cancellationTokenSource.Dispose();
    public void Dispose() => CancellationTokenSource.Dispose();
}
