using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Anikin.ViewModels.Components;
using Microsoft.Maui.Storage;
using SQLite;

namespace Anikin.Utils;

public class DownloadHistoryDatabase
{
    private SQLiteAsyncConnection Database = default!;

    async Task Init()
    {
        if (Database is not null)
            return;

        Database = new SQLiteAsyncConnection(Constants.DatabasePath, Constants.Flags);
        var result = await Database.CreateTableAsync<DownloadItem>();
    }

    public async Task<DownloadItem> GetItemAsync(int id)
    {
        await Init();
        return await Database.Table<DownloadItem>().FirstOrDefaultAsync(i => i.Id == id);
    }

    public async Task<List<DownloadItem>> GetItemsAsync()
    {
        await Init();
        return await Database.Table<DownloadItem>().ToListAsync();
    }

    public async Task<int> SaveItemAsync(DownloadItem item)
    {
        await Init();
        if (item.Id != 0)
            return await Database.UpdateAsync(item);
        else
            return await Database.InsertAsync(item);
    }

    public async Task<int> AddItemAsync(DownloadItem item)
    {
        await Init();
        return await Database.InsertAsync(item);
    }

    public async Task<int> AddItemsAsync(IEnumerable<DownloadItem> items)
    {
        await Init();
        return await Database.InsertAllAsync(items);
    }

    public async Task<int> DeleteItemAsync(DownloadItem item)
    {
        await Init();
        return await Database.DeleteAsync(item);
    }

    public async Task<int> DeleteAllAsync()
    {
        await Init();
        return await Database.DeleteAllAsync<DownloadItem>();
    }
}

public static class Constants
{
    public const string DatabaseFilename = "AnikinHistory.db3";

    public const SQLiteOpenFlags Flags =
        SQLiteOpenFlags.ReadWrite | SQLiteOpenFlags.Create | SQLiteOpenFlags.SharedCache;

    public static string DatabasePath =>
        Path.Combine(FileSystem.AppDataDirectory, DatabaseFilename);
}
