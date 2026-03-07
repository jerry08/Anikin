namespace Anikin.Utils;

public static partial class NotificationHelper
{
#if !ANDROID
    public static void UpdateProgress(string title, int progress, int max = 100) { }
#endif
}
