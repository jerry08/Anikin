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

namespace AniStream.Utils
{
    public class FileSizeToStringConverter
    {
        public static FileSizeToStringConverter Instance { get; } = new FileSizeToStringConverter();

        private static readonly string[] Units = { "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB" };

        public string Convert(double value)
        {
            double size = value;
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
}