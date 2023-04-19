using Android.Content;
using Android.Util;
using Android.Views;

namespace AniStream.Utils;

public class SpinnerNoSwipeSimpleGestureListener : GestureDetector.SimpleOnGestureListener
{
    private readonly SpinnerNoSwipe _spinnerNoSwipe;

    public SpinnerNoSwipeSimpleGestureListener(SpinnerNoSwipe spinnerNoSwipe)
    {
        _spinnerNoSwipe = spinnerNoSwipe;
    }

    public override bool OnSingleTapUp(MotionEvent e)
    {
        return _spinnerNoSwipe.PerformClick();
    }
}

public class SpinnerNoSwipe : AndroidX.AppCompat.Widget.AppCompatSpinner
{
    private GestureDetector? mGestureDetector { get; set; }

    public SpinnerNoSwipe(Context context) : base(context)
    {
        Setup();
    }

    public SpinnerNoSwipe(
        Context context,
        IAttributeSet? attrs) : base(context, attrs)
    {
        Setup();
    }

    public SpinnerNoSwipe(
        Context context,
        IAttributeSet? attrs,
        int defStyleAttr) : base(context, attrs, defStyleAttr)
    {
        Setup();
    }

    private void Setup()
    {
        mGestureDetector = new GestureDetector(
            Context,
            new SpinnerNoSwipeSimpleGestureListener(this)
        );
    }

    public override bool OnTouchEvent(MotionEvent? e)
    {
        if (e is not null)
            mGestureDetector?.OnTouchEvent(e);

        return true;
    }
}