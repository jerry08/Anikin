using System;
using Android.Graphics;
using Android.Text;
using Android.Text.Style;
using Android.Views;

namespace AniStream.Utils;

public class MySpannableEventArgs :EventArgs
{
    public View View = default!;
}

public class MySpannable : ClickableSpan
{
    public event EventHandler<MySpannableEventArgs>? MyClickEvent;

    private bool IsUnderline = true;

    public MySpannable(bool isUnderline)
    {
        IsUnderline = isUnderline;
    }

    public override void UpdateDrawState(TextPaint ds)
    {
        ds.UnderlineText = IsUnderline;
        ds.Color = Color.White;

        //base.UpdateDrawState(ds);
    }

    public override void OnClick(View widget)
    {
        var myClickEvent = new MySpannableEventArgs();
        myClickEvent.View = widget;

        MyClickEvent?.Invoke(this, myClickEvent);
    }
}