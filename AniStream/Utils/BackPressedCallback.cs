using System;
using AndroidX.Activity;

namespace AniStream.Utils;

public class BackPressedCallback : OnBackPressedCallback
{
    private readonly EventHandler? _action;

    public BackPressedCallback(bool enabled) : base(enabled)
    {
    }

    public BackPressedCallback(bool enabled,
        EventHandler action) : base(enabled)
    {
        _action = action;
    }

    public override void HandleOnBackPressed()
    {
        _action?.Invoke(this, new EventArgs());
    }
}