using Android.Content;
using AnimeDl;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xamarin.Essentials;

namespace AniStream.Utils
{
    internal class BookmarkManager
    {
        public async Task<bool> IsBookmarked(Anime anime)
        {
            var list = await GetBookmarks();

            Anime animeBookmarked = list.Where(x => x.Category == anime.Category)
                .FirstOrDefault();
            if (animeBookmarked != null)
            {
                return true;
            }

            return false;
        }

        public async Task<List<Anime>> GetBookmarks()
        {
            var json = await SecureStorage.GetAsync("bookmarks");

            var animes = new List<Anime>();

            if (!string.IsNullOrEmpty(json))
            {
                animes = JsonConvert.DeserializeObject<List<Anime>>(json);
                animes = animes.Where(x => x.Site == WeebUtils.AnimeSite).ToList();
            }

            return animes;
        }

        public async void SaveBookmark(Anime anime)
        {
            var animes = await GetBookmarks();
            animes.Add(anime);

            var json = JsonConvert.SerializeObject(animes);

            SecureStorage.SetAsync("bookmarks", json).Wait();
        }

        public async void RemoveBookmark(Anime anime)
        {
            var animes = await GetBookmarks();

            var animeToRemove = animes.Where(x => x.Category == anime.Category)
                .FirstOrDefault();
            if (animeToRemove != null)
            {
                animes.Remove(animeToRemove);
            }

            var json = JsonConvert.SerializeObject(animes);

            SecureStorage.SetAsync("bookmarks", json).Wait();
        }

        public void RemoveAllBookmarks()
        {
            SecureStorage.SetAsync("bookmarks", "").Wait();
        }

        public static float GetLastWatchedEp(Context context, Anime anime)
        {
            var bookmarksPref = context.GetSharedPreferences("lastWatchedPref", FileCreationMode.Private);

            var list = new List<Anime>();

            var lastWatchedStr = bookmarksPref.GetString("lastWatched", string.Empty);
            if (!string.IsNullOrEmpty(lastWatchedStr))
            {
                list = JsonConvert.DeserializeObject<List<Anime>>(lastWatchedStr);
            }

            if (list != null)
            {
                var anime2 = list.Where(x => x.Category == anime.Category)
                    .FirstOrDefault();
                if (anime2 != null)
                {
                    return anime2.LastWatchedEp;
                }
            }

            return 0;
        }

        public static void SaveLastWatchedEp(Context context, Anime anime)
        {
            var lastWatchedPref = context.GetSharedPreferences("lastWatchedPref", FileCreationMode.Private);
            var lastWatched = lastWatchedPref.Edit();

            var list = new List<Anime>();

            string lastWatchedStr = lastWatchedPref.GetString("lastWatched", string.Empty);
            if (string.IsNullOrEmpty(lastWatchedStr))
            {
                list.Add(anime);

                lastWatchedStr = JsonConvert.SerializeObject(list);

                lastWatched.PutString("lastWatched", lastWatchedStr);
                lastWatched.Commit();
            }
            else
            {
                list = JsonConvert.DeserializeObject<List<Anime>>(lastWatchedStr);
                var anime2 = list.Where(x => x.Category == anime.Category)
                    .FirstOrDefault();

                if (anime2 == null)
                {
                    list.Add(anime);
                }
                else
                {
                    if (anime.LastWatchedEp >= anime2.LastWatchedEp)
                    {
                        list.Remove(anime2);
                        list.Add(anime);
                    }
                }

                lastWatched.PutString("lastWatched", JsonConvert.SerializeObject(list));
                lastWatched.Commit();
            }
        }
    }
}