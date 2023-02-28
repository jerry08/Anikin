using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using AnimeDl.Models;
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
            .Where(x => x.Name == nameof(Anime.Id)
                || x.Name == nameof(Anime.Title)
                || x.Name == nameof(Anime.Category)
                || x.Name == nameof(Anime.Site)
                || x.Name == nameof(Anime.Image));

        return allProps.Where(p => props.Any(a => a.Name == p.PropertyName)).ToList();
    }
}