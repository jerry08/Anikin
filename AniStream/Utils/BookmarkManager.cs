using Android.Content;
using AnimeDl;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using Xamarin.Essentials;

namespace AniStream.Utils
{
    internal class BookmarkManager
    {
        public bool IsBookmarked(Anime anime)
        {
            List<Anime> list = GetBookmarks();

            Anime animeBookmarked = list.Where(x => x.Category == anime.Category)
                .FirstOrDefault();
            if (animeBookmarked != null)
            {
                return true;
            }

            return false;
        }

        public List<Anime> GetBookmarks()
        {
            var task = SecureStorage.GetAsync("bookmarks");
            task.Wait();
            string json = task.Result;

            List<Anime> animes = new List<Anime>();

            if (!string.IsNullOrEmpty(json))
            {
                animes = JsonConvert.DeserializeObject<List<Anime>>(json);
                animes = animes.Where(x => x.Site == WeebUtils.AnimeSite).ToList();
            }

            return animes;
        }

        public void SaveBookmark(Anime anime)
        {
            List<Anime> animes = GetBookmarks();
            animes.Add(anime);

            string json = JsonConvert.SerializeObject(animes);

            SecureStorage.SetAsync("bookmarks", json).Wait();
        }

        /*public void RemoveBookmark(Context context, Anime anime)
        {
            ISharedPreferences bookmarksPref = context.GetSharedPreferences("bookmarksPref", FileCreationMode.Private);

            //settingsPref.Edit().PutString("settings", null).Commit();

            ISharedPreferencesEditor bookmarks = bookmarksPref.Edit();

            List<Anime> list = new List<Anime>();

            string bookmarksStr = bookmarksPref.GetString("bookmarks", string.Empty);
            if (!string.IsNullOrEmpty(bookmarksStr))
            {
                list = JsonConvert.DeserializeObject<List<Anime>>(bookmarksStr);
                Anime animeBookmarked = list.Where(x => x.Category == anime.Category)
                    .FirstOrDefault();
                if (animeBookmarked != null)
                {
                    list.Remove(animeBookmarked);
                    bookmarks.PutString("bookmarks", JsonConvert.SerializeObject(list));
                    bookmarks.Commit();
                }
            }
        }*/
        public void RemoveBookmark(Anime anime)
        {
            List<Anime> animes = GetBookmarks();

            var animeToRemove = animes.Where(x => x.Category == anime.Category)
                .FirstOrDefault();

            if (animeToRemove != null)
            {
                animes.Remove(animeToRemove);
            }

            string json = JsonConvert.SerializeObject(animes);

            SecureStorage.SetAsync("bookmarks", json).Wait();
        }

        public void RemoveAllBookmarks()
        {
            SecureStorage.SetAsync("bookmarks", "").Wait();
        }

        public static float GetLastWatchedEp(Context context, Anime anime)
        {
            ISharedPreferences bookmarksPref = context.GetSharedPreferences("lastWatchedPref", FileCreationMode.Private);

            List<Anime> list = new List<Anime>();

            string lastWatchedStr = bookmarksPref.GetString("lastWatched", string.Empty);
            if (!string.IsNullOrEmpty(lastWatchedStr))
            {
                list = JsonConvert.DeserializeObject<List<Anime>>(lastWatchedStr);
            }

            if (list != null)
            {
                Anime anime2 = list.Where(x => x.Category == anime.Category)
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
            ISharedPreferences lastWatchedPref = context.GetSharedPreferences("lastWatchedPref", FileCreationMode.Private);

            ISharedPreferencesEditor lastWatched = lastWatchedPref.Edit();

            List<Anime> list = new List<Anime>();

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
                Anime anime2 = list.Where(x => x.Category == anime.Category)
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