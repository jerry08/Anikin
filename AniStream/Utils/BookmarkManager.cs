using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Firebase.Auth;
using Firebase.Database;
using Juro.Models.Anime;
using Microsoft.Maui.Storage;

namespace AniStream.Utils;

public class BookmarkManager
{
    private readonly string _name;

    public BookmarkManager(string name)
    {
        _name = name;
    }

    public async Task<bool> IsBookmarked(IAnimeInfo anime)
    {
        var list = await GetAllBookmarksAsync();
        return list.Find(x => x.Id == anime.Id) is not null;
    }

    public async Task<List<IAnimeInfo>> GetBookmarks()
    {
        var list = await GetAllBookmarksAsync();

        return list.Where(x => x.Site == WeebUtils.AnimeSite).ToList();
    }

    public async Task<List<IAnimeInfo>> GetAllBookmarksAsync()
    {
        var json = await SecureStorage.GetAsync(_name);

        var list = new List<IAnimeInfo>();

        if (!string.IsNullOrEmpty(json))
            list.AddRange(JsonSerializer.Deserialize<List<AnimeInfo>>(json)!);

        list.RemoveAll(x => string.IsNullOrEmpty(x.Category)
            && string.IsNullOrEmpty(x.Image) && string.IsNullOrEmpty(x.Link));

        return list;
    }

    public async Task SaveBookmarkAsync(IAnimeInfo anime, bool addToTop = false)
    {
        var animes = await GetAllBookmarksAsync();
        if (addToTop)
            animes.Insert(0, anime);
        else
            animes.Add(anime);

        var query = animes.Select(x => new
        {
            x.Id,
            x.Title,
            x.Category,
            x.Site,
            x.Image
        });

        var json = JsonSerializer.Serialize(query);

        await SecureStorage.SetAsync(_name, json);

        await SaveToCloudAsync();
    }

    public async Task RemoveBookmarkAsync(IAnimeInfo anime)
    {
        var animes = await GetAllBookmarksAsync();

        var animeToRemove = animes.Find(x => x.Id == anime.Id);

        if (animeToRemove is not null)
            animes.Remove(animeToRemove);

        var json = JsonSerializer.Serialize(animes);

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

        var list = await GetAllBookmarksAsync();

        var query = list.Select(x => new
        {
            x.Id,
            x.Title,
            x.Category,
            x.Site,
            x.Image
        });

        var data = JsonSerializer.Serialize(query);

        await userRef.Child(_name).SetValueAsync(data);
    }
}