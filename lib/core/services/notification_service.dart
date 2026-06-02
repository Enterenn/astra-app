import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

typedef NotificationPermissionChecker = Future<PermissionStatus> Function();

typedef GoalNotificationPresenter = Future<void> Function({
  required int id,
  required String title,
  String? body,
});

/// Local-only goal notifications (FR25). No FCM / scheduled nudges.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPermissionChecker? permissionChecker,
    this._goalNotificationPresenter,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _permissionChecker =
           permissionChecker ?? (() => Permission.notification.status);

  static const int goalNotificationId = 1;
  static const String goalChannelId = 'astra_goal_reached';
  static const String goalChannelName = 'Daily goal';
  static const String goalReachedTitle = 'Daily goal reached';

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPermissionChecker _permissionChecker;
  final GoalNotificationPresenter? _goalNotificationPresenter;

  bool _initialized = false;

  bool get _usesPlatformPresenter => _goalNotificationPresenter == null;

  /// UI isolate init — call from [main] after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _initializePlatform();
  }

  /// WorkManager isolate — same minimal init after binding + plugin registrant.
  Future<bool> initializeForBackground() async {
    if (!_usesPlatformPresenter) {
      _initialized = true;
      return true;
    }
    await initialize();
    return _initialized;
  }

  Future<void> _initializePlatform() async {
    if (!_usesPlatformPresenter) {
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
      debugPrint('NotificationService init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> hasNotificationPermission() async {
    final status = await _permissionChecker();
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<void> showGoalReached({int? stepsToday}) async {
    if (!await hasNotificationPermission()) {
      return;
    }

    if (_usesPlatformPresenter) {
      if (!_initialized) {
        await initialize();
      }
      if (!_initialized) {
        return;
      }
    }

    final body = stepsToday != null ? '$stepsToday steps today' : null;
    final presenter = _goalNotificationPresenter ?? _platformShowGoalReached;
    await presenter(
      id: goalNotificationId,
      title: goalReachedTitle,
      body: body,
    );
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
