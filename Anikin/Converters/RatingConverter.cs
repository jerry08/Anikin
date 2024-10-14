using System;
using System.Globalization;
using Microsoft.Maui.Controls;

namespace Anikin.Converters;

public class RatingConverter : IValueConverter
{
    public object? Convert(
        object? value,
        Type targetType,
        object? parameter,
        CultureInfo culture
    ) =>
        float.TryParse(value?.ToString(), out var score)
            ? string.Format("{0:0.0}", score / 10f)
            : "??";

    public object ConvertBack(
        object? value,
        Type targetType,
        object? parameter,
        CultureInfo culture
    ) => throw new NotSupportedException();
}
