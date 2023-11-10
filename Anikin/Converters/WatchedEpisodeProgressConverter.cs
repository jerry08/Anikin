using System;
using System.Globalization;
using Microsoft.Maui.Controls;

namespace Anikin.Converters;

public class WatchedEpisodeProgressConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object parameter, CultureInfo culture) =>
        float.TryParse(value?.ToString(), out var progress) ? progress / 100f : 0;

    public object ConvertBack(
        object? value,
        Type targetType,
        object parameter,
        CultureInfo culture
    ) => throw new NotSupportedException();
}
