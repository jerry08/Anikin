using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Reflection;

namespace Anikin.Utils.Extensions;

public static class EnumExtensions
{
    public static TAttribute? GetAttribute<TAttribute>(this Enum value)
        where TAttribute : Attribute =>
        value
            .GetType()
            .GetMember(value.ToString())
            .FirstOrDefault()
            ?.GetCustomAttribute<TAttribute>();

    public static string ToDescription(this Enum value)
    {
        var attribute = GetAttributes<DescriptionAttribute>(value).SingleOrDefault();

        return attribute?.Description ?? value.ToString();
    }

    private static List<TAttribute> GetAttributes<TAttribute>(Enum value)
        where TAttribute : Attribute
    {
        var list = new List<TAttribute>();

        var type = value.GetType();
        var fieldInfo = type.GetField(Enum.GetName(type, value) ?? string.Empty);

        if (fieldInfo is not null)
        {
            list.AddRange(
                (TAttribute[])Attribute.GetCustomAttributes(fieldInfo, typeof(TAttribute))
            );
        }

        return list;
    }

    public static string GetBestDisplayName(this Enum value) =>
        GetAttribute<DisplayAttribute>(value)?.Name
        ?? GetAttribute<DescriptionAttribute>(value)?.Description
        ?? value.ToString();
}
