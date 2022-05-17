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

namespace AniStream.ViewHolders
{
    public class ViewHolder : Java.Lang.Object
    {
        public int Id { get; set; }
        public TextView Name { get; set; }
        public TextView Released { get; set; }
        public ImageView Photo { get; set; }
        public ImageView OptionImage { get; set; }
        public Button DownloadBtn { get; set; }
    }
}