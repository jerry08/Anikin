using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Text;
using Android.Views;
using Android.Widget;
using Java.Lang;

namespace AniStream.Utils
{
    public class InputFilterMinMax : Java.Lang.Object, IInputFilter
    {
        private int min, max;

        public InputFilterMinMax(int min, int max)
        {
            this.min = min;
            this.max = max;
        }

        public InputFilterMinMax(string min, string max)
        {
            this.min = Convert.ToInt32(min);
            this.max = Convert.ToInt32(max);
        }

        public ICharSequence FilterFormatted(ICharSequence source, int start, int end, ISpanned dest, int dstart, int dend)
        {
            try
            {
                int input = Convert.ToInt32(dest.ToString() + source.ToString());
                if (IsInRange(min, max, input))
                    return null;
            }
            catch (Java.Lang.Exception nfe) 
            {
                
            }

            return new Java.Lang.String("");
        }

        private bool IsInRange(int a, int b, int c)
        {
            return b > a ? c >= a && c <= b : c >= b && c <= a;
        }
    }
}