/// Injectable Android-native capability reads (battery exemption, OEM manufacturer).
///
/// Tests use fakes — never hit the platform channel in unit tests.
abstract class PlatformCapabilityProbe {
  const PlatformCapabilityProbe();

  /// Whether the app is exempt from battery optimization (Android only).
  Future<bool> isBatteryOptimizationExempt();

  /// Device manufacturer string from `Build.MANUFACTURER`, or `null` when unavailable.
  Future<String?> getDeviceManufacturer();
}

/// Non-Android platforms: battery checks are N/A; no manufacturer probe.
class NoopPlatformCapabilityProbe extends PlatformCapabilityProbe {
  const NoopPlatformCapabilityProbe();

  @override
  Future<bool> isBatteryOptimizationExempt() async => true;

  @override
  Future<String?> getDeviceManufacturer() async => null;
}
