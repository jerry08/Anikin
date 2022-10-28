using System;

namespace AniStream.Settings;

/// <summary>
/// Specifies that the marked property does not need to be serialized
/// </summary>
[AttributeUsage(AttributeTargets.Property)]
public class IgnoreAttribute : Attribute
{
}