using System;
using Android.Media;
using Android.Runtime;

namespace AniStream.Utils.Listeners;

public class AudioFocusChangeListener
    : Java.Lang.Object, AudioManager.IOnAudioFocusChangeListener
{
    public EventHandler<AudioFocus>? OnAudioFocusChanged;

    public void OnAudioFocusChange([GeneratedEnum] AudioFocus focusChange)
        => OnAudioFocusChanged?.Invoke(this, focusChange);
}