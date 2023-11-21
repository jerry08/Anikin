using Anikin.ViewModels.Framework;
using CommunityToolkit.Mvvm.ComponentModel;

namespace Anikin.ViewModels.Popups;

public partial class LoadingPopupViewModel : BaseViewModel
{
    [ObservableProperty]
    string _loadingText = "";
}
