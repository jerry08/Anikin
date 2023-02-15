using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace AniStream.Settings.Serialization;

internal sealed class ContractResolver : DefaultContractResolver
{
    public static ContractResolver Instance { get; } = new();

    private static bool IsIgnored(Type declaringType, string propertyName)
    {
        var prop = declaringType.GetProperty(propertyName);
        return prop?.GetCustomAttributes(typeof(IgnoreAttribute), false).Any() == true;
    }

    protected override IList<JsonProperty> CreateProperties(Type type, MemberSerialization memberSerialization)
    {
        return base.CreateProperties(type, memberSerialization)
            // Not ignored
            .Where(p => p.UnderlyingName is not null && !IsIgnored(type, p.UnderlyingName))
            .ToList();
    }
}