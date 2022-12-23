namespace AniStream.Utils;

public class FileSizeToStringConverter
{
    public static FileSizeToStringConverter Instance { get; } = new FileSizeToStringConverter();

    private static readonly string[] Units = { "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB" };

    public string Convert(double value)
    {
        var size = value;
        var unit = 0;

        while (size >= 1024)
        {
            size /= 1024;
            ++unit;
        }

        var test = $"{size:0.#} {Units[unit]}";
        var test2 = $"{size:0.##} {Units[unit]}";

        return test2;
    }

    public string Convert(int value)
    {
        double size = value;
        var unit = 0;

        while (size >= 1024)
        {
            size /= 1024;
            ++unit;
        }

        return $"{size:0.#} {Units[unit]}";
    }
}