import 'package:astra_app/core/services/health_foreground_service.dart';
import 'package:flutter/services.dart';

/// Test double that records FGS lifecycle calls without touching the platform.
class RecordingHealthFgs extends HealthForegroundServiceCoordinator {
  RecordingHealthFgs({required this.calls})
    : super(
        channel: const MethodChannel('test/health_fgs'),
        activityPermissionGranted: () async => true,
        isAndroidPlatform: () => true,
      );

  final List<String> calls;

  @override
  Future<void> startHealthCollectionService() async {
    calls.add('start');
  }

  @override
  Future<void> stopHealthCollectionService() async {
    calls.add('stop');
  }

  @override
  Future<void> setUiActive(bool active) async {
    calls.add('uiActive:$active');
  }
}
