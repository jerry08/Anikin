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

        var animeBookmarked = list.Find(x => x.Id == anime.Id);

        return animeBookmarked is not null;
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

        var json = JsonConvert.SerializeObject(animes);

        await SecureStorage.SetAsync(_name, json);
    }

    public async Task RemoveBookmarkAsync(Anime anime)
    {
        var animes = await GetBookmarks();

        var animeToRemove = animes.Find(x => x.Id == anime.Id);

        if (animeToRemove is not null)
            animes.Remove(animeToRemove);

        var json = JsonConvert.SerializeObject(animes);

        await SecureStorage.SetAsync(_name, json);
    }

    public void RemoveAllBookmarks()
        => SecureStorage.Remove(_name);
}