import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFeature {
  advancedSearch,
  richMediaDetails,
  sourceFallback,
  media3Player,
  communityTimestamps,
  notifications,
  glassUi,
  novelReader,
  lnReaderPlugins,
  androidTv,
}

class FeatureGateService extends ChangeNotifier {
  FeatureGateService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _prefix = 'features.';

  SharedPreferences? _preferences;
  final Map<AppFeature, bool> _overrides = {};

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    for (final feature in AppFeature.values) {
      final saved = _preferences!.getBool('$_prefix${feature.name}');
      if (saved != null) {
        _overrides[feature] = saved;
      }
    }
  }

  bool isEnabled(AppFeature feature) =>
      _overrides[feature] ?? _defaultValue(feature);

  Future<void> setEnabled(AppFeature feature, bool enabled) async {
    _overrides[feature] = enabled;
    await _preferences!.setBool('$_prefix${feature.name}', enabled);
    notifyListeners();
  }

  bool _defaultValue(AppFeature feature) => switch (feature) {
    AppFeature.advancedSearch => true,
    AppFeature.richMediaDetails => true,
    AppFeature.sourceFallback => true,
    AppFeature.communityTimestamps => true,
    AppFeature.notifications => true,
    AppFeature.glassUi => true,
    AppFeature.media3Player ||
    AppFeature.lnReaderPlugins ||
    AppFeature.androidTv => false,
    AppFeature.novelReader => true,
  };
}
