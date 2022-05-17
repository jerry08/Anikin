using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.Graphics;
using Android.OS;
using Android.Runtime;
using Android.Text;
using Android.Text.Style;
using Android.Views;
using Android.Widget;

namespace AniStream.Utils
{
    public class MySpannableEventArgs :EventArgs
    {
        public View View;
    }

    public class MySpannable : ClickableSpan
    {
        public event EventHandler<MySpannableEventArgs> MyClickEvent;

        private bool isUnderline = true;

        public MySpannable(bool isUnderline)
        {
            this.isUnderline = isUnderline;
        }

        public override void UpdateDrawState(TextPaint ds)
        {
            ds.UnderlineText = isUnderline;
            ds.Color = Color.White;

            //base.UpdateDrawState(ds);
        }

        public override void OnClick(View widget)
        {
            var myClickEvent = new MySpannableEventArgs();
            myClickEvent.View = widget;

            MyClickEvent(this, myClickEvent);
        }
    }
}