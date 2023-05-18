using Android.Content;
using Android.Views;
using Android.Widget;

namespace AniStream.Utils.Tags;

public class GenreTag
{
    public View GetGenreTag(Context context, string genreName)
    {
        var view = LayoutInflater.From(context)!.Inflate(Resource.Layout.tags_genre, null)!;
        var button = view.FindViewById<TextView>(Resource.Id.genre)!;
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