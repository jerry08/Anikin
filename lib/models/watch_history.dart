class WatchedEpisode {
  const WatchedEpisode({
    required this.id,
    required this.animeName,
    required this.watchedDurationMs,
    required this.watchedPercentage,
  });

  final String id;
  final String animeName;
  final int watchedDurationMs;
  final double watchedPercentage;

  Duration get watchedDuration => Duration(milliseconds: watchedDurationMs);

  Map<String, dynamic> toJson() => {
    'id': id,
    'animeName': animeName,
    'watchedDuration': watchedDurationMs,
    'watchedPercentage': watchedPercentage,
  };

  factory WatchedEpisode.fromJson(Map<String, dynamic> json) {
    return WatchedEpisode(
      id: json['id']?.toString() ?? '',
      animeName: json['animeName']?.toString() ?? '',
      watchedDurationMs: (json['watchedDuration'] as num?)?.toInt() ?? 0,
      watchedPercentage: (json['watchedPercentage'] as num?)?.toDouble() ?? 0,
    );
  }
}
