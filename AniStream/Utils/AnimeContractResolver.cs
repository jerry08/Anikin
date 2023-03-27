using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Juro.Models.Anime;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace AniStream.Utils;

internal sealed class AnimeContractResolver : DefaultContractResolver
{
    private readonly bool _ignoreBase;

    public AnimeContractResolver(bool ignoreBase)
    {
        _ignoreBase = ignoreBase;
    }

    protected override IList<JsonProperty> CreateProperties(Type type, MemberSerialization memberSerialization)
    {
        var allProps = base.CreateProperties(type, memberSerialization);
        if (!_ignoreBase)
            return allProps;

        //Choose the properties you want to serialize/deserialize
        var props = type.GetProperties(~BindingFlags.FlattenHierarchy)
            .Where(x => x.Name == nameof(AnimeInfo.Id)
                || x.Name == nameof(AnimeInfo.Title)
                || x.Name == nameof(AnimeInfo.Category)
                || x.Name == nameof(AnimeInfo.Site)
                || x.Name == nameof(AnimeInfo.Image));

        return allProps.Where(p => props.Any(a => a.Name == p.PropertyName)).ToList();
    }
}