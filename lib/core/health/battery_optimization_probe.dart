import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const _aggressiveOemManufacturers = {
  'samsung',
  'xiaomi',
  'huawei',
  'oppo',
  'vivo',
  'oneplus',
  'realme',
};

bool likelyOemBatteryDeferral({
  required String? manufacturer,
  required bool batteryOptimizationExempt,
}) {
  if (batteryOptimizationExempt || manufacturer == null) {
    return false;
  }
  final normalized = manufacturer.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return _aggressiveOemManufacturers.any(normalized.contains);
}

class BatteryOptimizationProbe {
  BatteryOptimizationProbe({
    MethodChannel? channel,
    Future<PermissionStatus> Function()? requestExemption,
    bool Function()? isAndroidPlatform,
  }) : _channel = channel ?? _defaultChannel,
       _requestExemption =
           requestExemption ??
           (() => Permission.ignoreBatteryOptimizations.request()),
       _isAndroidPlatform = isAndroidPlatform ?? (() => Platform.isAndroid);

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.astraapp.astra_app/background_health_capability',
  );

  static const String _methodBatteryExempt = 'isIgnoringBatteryOptimizations';
  static const String _methodManufacturer = 'getDeviceManufacturer';

  final MethodChannel _channel;
  final Future<PermissionStatus> Function() _requestExemption;
  final bool Function() _isAndroidPlatform;

  Future<bool> isExempt() async {
    if (!_isAndroidPlatform()) {
      return true;
    }
    try {
      final exempt = await _channel.invokeMethod<bool>(_methodBatteryExempt);
      return exempt ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> deviceManufacturer() async {
    if (!_isAndroidPlatform()) {
      return null;
    }
    try {
      final manufacturer = await _channel.invokeMethod<String>(
        _methodManufacturer,
      );
      final trimmed = manufacturer?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> requestExemption() async {
    if (!_isAndroidPlatform()) {
      return true;
    }
    final status = await _requestExemption();
    return status.isGranted;
  }
}
