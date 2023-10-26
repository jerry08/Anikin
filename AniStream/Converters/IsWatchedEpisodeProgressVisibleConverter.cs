using System;
using System.Globalization;
using Microsoft.Maui.Controls;

namespace AniStream.Converters;

public class IsWatchedEpisodeProgressVisibleConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object parameter, CultureInfo culture) =>
        float.TryParse(value?.ToString(), out var progress)
            && progress > 0.2f;

    public object ConvertBack(object? value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
