using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AnimeDl.Models;
using Firebase.Auth;
using Firebase.Database;
using Microsoft.Maui.Storage;
using Newtonsoft.Json;

namespace AniStream.Utils;

public class BookmarkManager
{
    private readonly string _name;

    public BookmarkManager(string name)
    {
        _name = name;
    }

    public async Task<bool> IsBookmarked(Anime anime)
    {
        var list = await GetBookmarks();
        return list.Find(x => x.Id == anime.Id) is not null;
    }

    public async Task<List<Anime>> GetBookmarks()
    {
        var json = await SecureStorage.GetAsync(_name);

        var animes = new List<Anime>();

        if (!string.IsNullOrEmpty(json))
        {
            animes = JsonConvert.DeserializeObject<List<Anime>>(json)!;
            animes = animes.Where(x => x.Site == WeebUtils.AnimeSite).ToList();
        }

        return animes;
    }

    public async Task SaveBookmarkAsync(Anime anime, bool addToTop = false)
    {
        var animes = await GetBookmarks();
        if (addToTop)
            animes.Insert(0, anime);
        else
            animes.Add(anime);

        var settings = new JsonSerializerSettings()
        {
            ContractResolver = new AnimeContractResolver(true)
        };

        var json = JsonConvert.SerializeObject(animes, settings);

        await SecureStorage.SetAsync(_name, json);

        await SaveToCloudAsync();
    }

    public async Task RemoveBookmarkAsync(Anime anime)
    {
        var animes = await GetBookmarks();

        var animeToRemove = animes.Find(x => x.Id == anime.Id);

        if (animeToRemove is not null)
            animes.Remove(animeToRemove);

        var json = JsonConvert.SerializeObject(animes);

        await SecureStorage.SetAsync(_name, json);

        await SaveToCloudAsync();
    }

    public async Task RemoveAllBookmarksAsync()
    {
        SecureStorage.Remove(_name);
        await SaveToCloudAsync();
    }

    private async Task SaveToCloudAsync()
    {
        // Check if user is signed in (non-null)
        var currentUser = FirebaseAuth.Instance.CurrentUser;
        if (currentUser is null)
            return;

        var database = FirebaseDatabase.GetInstance("https://anistream-e4d6d-default-rtdb.firebaseio.com/");
        var userRef = database.Reference.Child($"users/{FirebaseAuth.Instance.CurrentUser.Uid}");

        //userRef.AddListenerForSingleValueEvent(new DeleteValueEventListener());

        //await userRef.Child("bookmarks").SetValueAsync("test1");
        //await userRef.Child("bookmarks").Push().SetValueAsync("test1");

        var list = await GetBookmarks();

        var settings = new JsonSerializerSettings()
        {
            ContractResolver = new AnimeContractResolver(true)
        };

        var data = JsonConvert.SerializeObject(list, settings);

        await userRef.Child(_name).SetValueAsync(data);
    }
}