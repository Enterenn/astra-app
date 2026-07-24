import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'workmanager_callback.dart';

@visibleForTesting
Future<void> startNotificationInitForBoot(
  NotificationService notificationService, {
  Future<void> Function(NotificationService service)? initialize,
}) async {
  final runInit = initialize ??
      ((service) => service.initialize().timeout(const Duration(seconds: 3)));
  try {
    await runInit(notificationService);
  } on TimeoutException catch (error) {
    debugPrint('NotificationService init timed out: $error');
  } catch (error, stackTrace) {
    debugPrint('NotificationService init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

/// Serializes WM step-collection cancel before notification init starts.
///
/// [notificationService] may be constructed before this gate; its constructor
/// has no platform side effects — only [NotificationService.initialize] is
/// gated after cancel to avoid WM isolate races (workmanager_callback.dart).
@visibleForTesting
Future<void> runBootGateBeforeDependencies({
  required NotificationService notificationService,
  Future<void> Function()? cancelStepCollection,
  Future<void> Function(NotificationService service)? startNotificationInit,
  void Function(Future<void> initFuture)? scheduleParallelInit,
}) async {
  final cancel = cancelStepCollection ?? cancelStepCollectionWorkmanager;
  final startInit = startNotificationInit ?? startNotificationInitForBoot;

  await cancel(); // barrier before UI-isolate notification plugin init

  final initFuture = startInit(notificationService);
  (scheduleParallelInit ?? unawaited)(initFuture);
}
