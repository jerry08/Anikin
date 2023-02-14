using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AnimeDl.Models;
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

        var animeBookmarked = list.Where(x => x.Id == anime.Id)
            .FirstOrDefault();

        if (animeBookmarked is not null)
            return true;

        return false;
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

    public async void SaveBookmark(Anime anime, bool addToTop = false)
    {
        var animes = await GetBookmarks();
        if (addToTop)
            animes.Insert(0, anime);
        else
            animes.Add(anime);

        var json = JsonConvert.SerializeObject(animes);

        SecureStorage.SetAsync(_name, json).Wait();
    }

    public async void RemoveBookmark(Anime anime)
    {
        var animes = await GetBookmarks();

        var animeToRemove = animes.Where(x => x.Id == anime.Id)
            .FirstOrDefault();

        if (animeToRemove is not null)
            animes.Remove(animeToRemove);

        var json = JsonConvert.SerializeObject(animes);

        SecureStorage.SetAsync(_name, json).Wait();
    }

    public void RemoveAllBookmarks()
        => SecureStorage.Remove(_name);
}