import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fgs_step_collection.dart';

typedef FgsStepCollectionRunner = Future<bool> Function({
  bool skipPhoneSourceWhenUiActive,
});

/// Android health FGS coordinator — platform channel + lifecycle policy hooks.
///
/// Pedometer coordination (single-writer):
/// | Foreground, process alive | LiveStepMonitor owns stream; FGS stopped |
/// | Background, process alive | FGS collects via PhonePedometer after pause flush |
/// | Process dead / recents swipe | FGS or WM isolate; PhonePedometer only |
class HealthForegroundServiceCoordinator {
  HealthForegroundServiceCoordinator({
    MethodChannel? channel,
    Future<bool> Function()? activityPermissionGranted,
    FgsStepCollectionRunner? collectionRunner,
    bool Function()? isAndroidPlatform,
  }) : _channel = channel ?? _defaultChannel,
       _activityPermissionGranted = activityPermissionGranted ?? (() async => true),
       _collectionRunner = collectionRunner ?? _defaultCollectionRunner,
       _isAndroidPlatform = isAndroidPlatform ?? (() => Platform.isAndroid);

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.astraapp.astra_app/health_foreground',
  );

  static const String _methodStart = 'startHealthCollectionService';
  static const String _methodStop = 'stopHealthCollectionService';
  static const String _methodIsRunning = 'isHealthCollectionServiceRunning';
  static const String _methodSetUiActive = 'setUiActive';
  static const String _methodCollect = 'collectSteps';

  final MethodChannel _channel;
  final Future<bool> Function() _activityPermissionGranted;
  final FgsStepCollectionRunner _collectionRunner;
  final bool Function() _isAndroidPlatform;

  bool _uiActive = true;
  bool _channelHandlerRegistered = false;

  /// Registers native → Dart collection invocations (idempotent).
  void registerPlatformHandlers() {
    if (_channelHandlerRegistered || !_isAndroidPlatform()) {
      return;
    }
    _channel.setMethodCallHandler(_onMethodCall);
    _channelHandlerRegistered = true;
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == _methodCollect) {
      await _collectionRunner(skipPhoneSourceWhenUiActive: _uiActive);
      return;
    }
    debugPrint('HealthForegroundService ignored method: ${call.method}');
  }

  Future<void> startHealthCollectionService() async {
    if (!_isAndroidPlatform()) {
      return;
    }
    if (!await _activityPermissionGranted()) {
      return;
    }
    registerPlatformHandlers();
    try {
      await _channel.invokeMethod<void>(_methodStart);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Health FGS start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> stopHealthCollectionService() async {
    if (!_isAndroidPlatform()) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_methodStop);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Health FGS stop failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> isHealthCollectionServiceRunning() async {
    if (!_isAndroidPlatform()) {
      return false;
    }
    try {
      final running = await _channel.invokeMethod<bool>(_methodIsRunning);
      return running ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Native defensive gate: skip phone pedometer reads while UI owns the stream.
  Future<void> setUiActive(bool active) async {
    _uiActive = active;
    if (!_isAndroidPlatform()) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_methodSetUiActive, active);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Health FGS setUiActive failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<bool> _defaultCollectionRunner({
    bool skipPhoneSourceWhenUiActive = false,
  }) {
    return runFgsStepCollectionCycle(
      skipPhoneSourceWhenUiActive: skipPhoneSourceWhenUiActive,
    );
  }
}
