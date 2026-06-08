import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

typedef NotificationPermissionChecker = Future<PermissionStatus> Function();

typedef GoalNotificationPresenter = Future<void> Function({
  required int id,
  required String title,
  String? body,
});

typedef NotificationPlatformInitializer = Future<void> Function(
  FlutterLocalNotificationsPlugin plugin,
);

/// Local-only goal notifications (FR25). No FCM / scheduled nudges.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPermissionChecker? permissionChecker,
    this._goalNotificationPresenter,
    this._platformInitializer,
    Duration? backgroundInitTimeout,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _permissionChecker =
           permissionChecker ?? (() => Permission.notification.status),
       _backgroundInitTimeout =
           backgroundInitTimeout ?? const Duration(seconds: 2);

  static const int goalNotificationId = 1;
  static const String goalChannelId = 'astra_goal_reached';
  static const String goalChannelName = 'Daily goal';
  static const String goalReachedTitle = 'Daily goal reached';

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPermissionChecker _permissionChecker;
  final GoalNotificationPresenter? _goalNotificationPresenter;
  final NotificationPlatformInitializer? _platformInitializer;
  final Duration _backgroundInitTimeout;

  bool _initialized = false;
  Future<void>? _initFuture;

  bool get _usesPlatformPresenter => _goalNotificationPresenter == null;

  /// UI isolate init — call from [main] after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initFuture ??= _initializePlatform();
    try {
      await _initFuture;
    } catch (_) {
      if (!_initialized) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  /// WorkManager isolate — same minimal init after binding + plugin registrant.
  Future<bool> initializeForBackground() async {
    if (!_usesPlatformPresenter) {
      _initialized = true;
      return true;
    }

    try {
      await initialize().timeout(_backgroundInitTimeout);
      return _initialized;
    } on TimeoutException catch (error) {
      debugPrint('NotificationService background init timed out: $error');
      return false;
    }
  }

  Future<void> _initializePlatform() async {
    if (!_usesPlatformPresenter) {
      _initialized = true;
      return;
    }

    if (_platformInitializer != null) {
      await _platformInitializer(_plugin);
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _plugin.initialize(settings: initSettings);
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          goalChannelId,
          goalChannelName,
        ),
      );
      _initialized = true;
    } catch (error, stackTrace) {
      _initFuture = null;
      debugPrint('NotificationService init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> hasNotificationPermission() async {
    final status = await _permissionChecker();
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  /// Returns `true` when the notification was presented; `false` on skip or failure.
  Future<bool> showGoalReached({int? stepsToday}) async {
    if (!await hasNotificationPermission()) {
      return false;
    }

    if (_usesPlatformPresenter) {
      if (!_initialized) {
        await initialize();
      }
      if (!_initialized) {
        return false;
      }
    }

    final body = stepsToday != null ? '$stepsToday steps today' : null;
    final presenter = _goalNotificationPresenter ?? _platformShowGoalReached;
    try {
      await presenter(
        id: goalNotificationId,
        title: goalReachedTitle,
        body: body,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('NotificationService.showGoalReached failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _platformShowGoalReached({
    required int id,
    required String title,
    String? body,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          goalChannelId,
          goalChannelName,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
