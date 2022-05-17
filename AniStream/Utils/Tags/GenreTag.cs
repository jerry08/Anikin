using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace AniStream.Utils.Tags
{
    internal class GenreTag
    {
        public View GetGenreTag(Context context, string genreName)
        {
            var view = LayoutInflater.From(context).Inflate(Resource.Layout.tags_genre, null);
            var button = view.FindViewById<TextView>(Resource.Id.genre);
            button.Text = genreName;
            button.SetMaxLines(1);

            var rel_button1 = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WrapContent,
                ViewGroup.LayoutParams.WrapContent
            );
            rel_button1.SetMargins(8, 8, 8, 8);
            button.LayoutParameters = rel_button1;
            return view;
        }
    }
}