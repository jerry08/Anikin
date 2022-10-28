using System;

namespace AniStream.Settings;

public abstract partial class SettingsManager : ICloneable
{
    /// <summary>
    /// Performs a deep copy of this <see cref="SettingsManager"/> instance
    /// </summary>
    public object Clone()
    {
        var clone = (SettingsManager)Activator.CreateInstance(GetType())!;
        clone.CopyFrom(this);
        return clone;
    }
}