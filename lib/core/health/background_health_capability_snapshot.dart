/// Immutable capability snapshot for passive health background collection (D-23).
///
/// Consumed by Epic 4.2 [BackgroundStatusCard] — this story exposes flags only;
/// no user-facing copy or settings flows here.
class BackgroundHealthCapabilitySnapshot {
  const BackgroundHealthCapabilitySnapshot({
    required this.activityRecognitionGranted,
    required this.notificationGranted,
    required this.batteryOptimizationExempt,
    required this.fgsHealthDeclared,
    required this.likelyOemBatteryDeferral,
    this.manufacturer,
  });

  /// Activity recognition (Android) or motion/sensors (iOS) permission granted.
  final bool activityRecognitionGranted;

  /// POST_NOTIFICATIONS (Android 13+) or iOS notification permission granted.
  final bool notificationGranted;

  /// `PowerManager.isIgnoringBatteryOptimizations` on Android; always `true` on iOS.
  final bool batteryOptimizationExempt;

  /// Manifest declares `HealthStepForegroundService` with `foregroundServiceType="health"`.
  /// Static declaration only — not whether the service is running.
  final bool fgsHealthDeclared;

  /// Hint: known aggressive OEM manufacturer and app is not battery-optimization exempt.
  /// Not proof that WorkManager is deferred; Epic 4.2 uses this for honest status UX.
  final bool likelyOemBatteryDeferral;

  /// `Build.MANUFACTURER` on Android; `null` on iOS and other platforms.
  final String? manufacturer;
}
