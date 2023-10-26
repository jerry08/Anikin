using System.Threading.Tasks;
using AniStream.ViewModels.Framework;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui.ApplicationModel;

namespace AniStream.ViewModels;

public partial class ProfileViewModel : BaseViewModel
{
    public ProfileViewModel()
    {
    }

    [RelayCommand]
    async Task LoginWithAnilist()
    {
        var clientID = "14733";

        var test = await Browser.Default.OpenAsync($"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token");
    }
}
