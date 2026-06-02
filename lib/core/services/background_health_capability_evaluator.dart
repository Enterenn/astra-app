import '../health/background_health_capability_snapshot.dart';
import '../health/background_health_manifest.dart';
import 'platform_capability_probe.dart';

/// Single entry point for passive background health capability state (architecture D-23).
///
/// Checks only — permission **request** flows stay in onboarding / settings (Epic 4.2).
class BackgroundHealthCapabilityEvaluator {
  BackgroundHealthCapabilityEvaluator({
    required this._activityRecognitionGranted,
    required this._notificationGranted,
    PlatformCapabilityProbe? platformProbe,
    bool Function()? isAndroidPlatform,
    this._fgsHealthDeclaredOnAndroid = kAndroidFgsHealthManifestDeclared,
  }) : _platformProbe = platformProbe ?? const NoopPlatformCapabilityProbe(),
       _isAndroidPlatform = isAndroidPlatform ?? (() => false);

  final Future<bool> Function() _activityRecognitionGranted;
  final Future<bool> Function() _notificationGranted;
  final PlatformCapabilityProbe _platformProbe;
  final bool Function() _isAndroidPlatform;
  final bool _fgsHealthDeclaredOnAndroid;

  static const Set<String> _aggressiveOemManufacturers = {
    'samsung',
    'xiaomi',
    'huawei',
    'oppo',
    'vivo',
    'oneplus',
    'realme',
  };

  Future<BackgroundHealthCapabilitySnapshot> evaluate() async {
    final isAndroid = _isAndroidPlatform();
    final activityGranted = await _activityRecognitionGranted();
    final notificationGranted = await _notificationGranted();
    final batteryExempt = isAndroid
        ? await _platformProbe.isBatteryOptimizationExempt()
        : true;
    final manufacturer = isAndroid
        ? await _platformProbe.getDeviceManufacturer()
        : null;
    final fgsDeclared = isAndroid && _fgsHealthDeclaredOnAndroid;
    final likelyDeferral =
        isAndroid &&
        !batteryExempt &&
        _isAggressiveOemManufacturer(manufacturer);

    return BackgroundHealthCapabilitySnapshot(
      activityRecognitionGranted: activityGranted,
      notificationGranted: notificationGranted,
      batteryOptimizationExempt: batteryExempt,
      fgsHealthDeclared: fgsDeclared,
      likelyOemBatteryDeferral: likelyDeferral,
      manufacturer: manufacturer,
    );
  }

  static bool _isAggressiveOemManufacturer(String? manufacturer) {
    if (manufacturer == null || manufacturer.isEmpty) {
      return false;
    }
    final normalized = manufacturer.trim().toLowerCase();
    return _aggressiveOemManufacturers.any(normalized.contains);
  }
}
