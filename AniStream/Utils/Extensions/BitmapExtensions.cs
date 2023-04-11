using Android.Graphics;

namespace AniStream.Utils.Extensions;

internal static class BitmapExtensions
{
    public static Bitmap GetRoundedCornerBitmap(
        this Bitmap bitmap,
        int roundPixelSize)
    {
        var output = Bitmap.CreateBitmap(bitmap.Width, bitmap.Height, Bitmap.Config.Argb8888);
        var canvas = new Canvas(output);
        var paint = new Paint();
        var rect = new Rect(0, 0, bitmap.Width, bitmap.Height);
        var rectF = new RectF(rect);
        float roundPx = roundPixelSize;
        paint.AntiAlias = true;
        canvas.DrawRoundRect(rectF, roundPx, roundPx, paint);
        paint.SetXfermode(new PorterDuffXfermode(PorterDuff.Mode.SrcIn));
        canvas.DrawBitmap(bitmap, rect, rect, paint);
        return output;
    }
}