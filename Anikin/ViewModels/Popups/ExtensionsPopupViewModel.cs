using Anikin.ViewModels.Framework;
using CommunityToolkit.Mvvm.ComponentModel;

namespace Anikin.ViewModels.Popups;

public partial class ExtensionsPopupViewModel : BaseViewModel
{
    [ObservableProperty]
    string? _repoUrl;
}
