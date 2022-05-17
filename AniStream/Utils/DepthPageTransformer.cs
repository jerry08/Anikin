using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AndroidX.ViewPager.Widget;

namespace AniStream.Utils
{
    public class DepthPageTransformer : Java.Lang.Object, ViewPager.IPageTransformer
    {
        private static float MIN_SCALE = 0.75f;

        public void TransformPage(View page, float position)
        {
            int pageWidth = page.Width;

            if (position < -1)
            { 
                // [ -Infinity,-1 )
                // This page is way off-screen to the left.
                page.Alpha = 0;
            }
            else if (position <= 0)
            { 
                // [-1,0]
                // Use the default slide transition when moving to the left page
                page.Alpha = 1;
                page.TranslationX = 0;
                page.ScaleX = 1;
                page.ScaleY = 1;
            }
            else if (position <= 1)
            { 
                // (0,1]
                // Fade the page out.
                page.Alpha = 1 - position;

                // Counteract the default slide transition
                page.TranslationX = pageWidth * -position ;

                // Scale the page down ( between MIN_SCALE and 1 )
                float scaleFactor = MIN_SCALE + (1 - MIN_SCALE) * (1 - Math.Abs(position));
                page.ScaleX = scaleFactor;
                page.ScaleY = scaleFactor;
            }
            else
            { 
                // ( 1, +Infinity ]
                // This page is way off-screen to the right.
                page.Alpha = 0;
            }
        }
    }
}