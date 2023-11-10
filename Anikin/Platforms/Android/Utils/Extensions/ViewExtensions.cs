using System;
using Android.Views;

namespace Anikin.Utils.Extensions;

public static class ViewExtensions
{
    public static void CircularReveal(this View view, int ex, int ey, bool subX, long time)
    {
        ViewAnimationUtils
            .CreateCircularReveal(
                view,
                subX ? ex - (int)view.GetX() : ex,
                ey - (int)view.GetY(),
                0f,
                Math.Max(view.Height, view.Width)
            )!
            .SetDuration(time)!
            .Start();
    }
}
