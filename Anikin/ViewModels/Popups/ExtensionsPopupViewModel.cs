using System.Threading.Tasks;
using Anikin.ViewModels.Framework;
using CommunityToolkit.Mvvm.ComponentModel;

namespace Anikin.ViewModels.Popups;

public partial class ExtensionsPopupViewModel : BaseViewModel
{
    [ObservableProperty]
    string _repoUrl = "";

    public async Task<bool> SaveAsync()
    {
        return true;
    }
}
