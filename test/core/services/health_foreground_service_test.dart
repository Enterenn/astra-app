import 'package:astra_app/core/services/health_foreground_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthForegroundServiceCoordinator', () {
    late List<MethodCall> platformCalls;
    late HealthForegroundServiceCoordinator coordinator;

    setUp(() {
      platformCalls = [];
      coordinator = HealthForegroundServiceCoordinator(
        channel: _RecordingChannel(platformCalls),
        activityPermissionGranted: () async => true,
        isAndroidPlatform: () => true,
      );
      coordinator.registerPlatformHandlers();
    });

    test('start and stop invoke platform methods when permission granted', () async {
      await coordinator.startHealthCollectionService();
      await coordinator.stopHealthCollectionService();

      expect(
        platformCalls.map((c) => c.method),
        [
          'startHealthCollectionService',
          'stopHealthCollectionService',
        ],
      );
    });

    test('start no-ops when activity permission denied', () async {
      final denied = HealthForegroundServiceCoordinator(
        channel: _RecordingChannel(platformCalls),
        activityPermissionGranted: () async => false,
        isAndroidPlatform: () => true,
      );

      await denied.startHealthCollectionService();

      expect(platformCalls, isEmpty);
    });

    test('setUiActive forwards flag to native', () async {
      await coordinator.setUiActive(false);
      await coordinator.setUiActive(true);

      expect(platformCalls.map((c) => c.method), ['setUiActive', 'setUiActive']);
      expect(platformCalls[0].arguments, isFalse);
      expect(platformCalls[1].arguments, isTrue);
    });

  });
}

class _RecordingChannel extends MethodChannel {
  _RecordingChannel(this.calls) : super('com.astraapp.astra_app/health_foreground');

  final List<MethodCall> calls;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    calls.add(MethodCall(method, arguments));
    if (method == 'isHealthCollectionServiceRunning') {
      return Future<T?>.value(false as T?);
    }
    return Future<T?>.value(null);
  }
}
