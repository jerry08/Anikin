namespace Anikin.Models;

public class WatchedEpisode
{
    public string Id { get; set; } = default!;

    public long WatchedDuration { get; set; }

    public float WatchedPercentage { get; set; }

    public string AnimeName { get; set; } = default!;
}
