using System;
using Android.Content;

namespace AniStream.Utils;

public class DialogClickListener : Java.Lang.Object, IDialogInterfaceOnClickListener
{
    public EventHandler<int>? OnItemClick;

    public void OnClick(IDialogInterface? dialog, int which)
    {
        OnItemClick?.Invoke(this, which);
    }
}