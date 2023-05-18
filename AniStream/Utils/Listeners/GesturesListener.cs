using System;
using System.Timers;
using Android.OS;
using Android.Views;

namespace AniStream.Utils.Listeners;

public class GesturesListener : GestureDetector.SimpleOnGestureListener
{
    private Timer Timer = new();
    private long Delay = 200;

    public EventHandler<MotionEvent>? OnSingleClick;

    public EventHandler<MotionEvent>? OnDoubleClick;

    public EventHandler<float>? OnScrollYClick;

    public EventHandler<float>? OnScrollXClick;

    public EventHandler<MotionEvent>? OnLongClick;

    public override bool OnSingleTapUp(MotionEvent e)
    {
        ProcessSingleClickEvent(e);
        return base.OnSingleTapUp(e);
    }

    public override void OnLongPress(MotionEvent e)
    {
        ProcessLongClickEvent(e);
        base.OnLongPress(e);
    }

    public override bool OnDoubleTap(MotionEvent e)
    {
        ProcessDoubleClickEvent(e);
        return base.OnDoubleTap(e);
    }

    public override bool OnScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY)
    {
        OnScrollYClick?.Invoke(this, distanceX);
        OnScrollXClick?.Invoke(this, distanceY);
        return base.OnScroll(e1, e2, distanceX, distanceY);
    }

    private void ProcessSingleClickEvent(MotionEvent e)
    {
        var handler = new Handler(Looper.MainLooper!);

        Timer = new()
        {
            Interval = Delay,
            AutoReset = false
        };

        Timer.Elapsed += (s, ev) =>
        {
            Timer.Stop();
            handler.Post(() => OnSingleClick?.Invoke(this, e));
        };

        Timer.Start();
    }

    private void ProcessDoubleClickEvent(MotionEvent e)
    {
        Timer.Stop();

        OnDoubleClick?.Invoke(this, e);
    }

    private void ProcessLongClickEvent(MotionEvent e)
    {
        Timer.Stop();

        OnLongClick?.Invoke(this, e);
    }
}