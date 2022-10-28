using Newtonsoft.Json;

namespace AniStream.Settings.Serialization;

/// <summary>
/// Performs serialization and deserialization
/// </summary>
public static class Serializer
{
    private static readonly JsonSerializerSettings JsonSerializerSettings = new JsonSerializerSettings
    {
        Formatting = Formatting.Indented,
        DefaultValueHandling = DefaultValueHandling.Include,
        ObjectCreationHandling = ObjectCreationHandling.Replace,
        ContractResolver = ContractResolver.Instance
    };

    /// <summary>
    /// Serialize object
    /// </summary>
    public static string Serialize(object obj)
    {
        return JsonConvert.SerializeObject(obj, JsonSerializerSettings);
    }

    /// <summary>
    /// Deserialize object
    /// </summary>
    public static T? Deserialize<T>(string serialized)
    {
        return JsonConvert.DeserializeObject<T>(serialized, JsonSerializerSettings);
    }

    /// <summary>
    /// Populate an existing object with serialized data
    /// </summary>
    public static void Populate(string serialized, object obj)
    {
        JsonConvert.PopulateObject(serialized, obj, JsonSerializerSettings);
    }
}