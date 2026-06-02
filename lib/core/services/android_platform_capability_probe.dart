import 'dart:io';

import 'package:flutter/services.dart';

import 'platform_capability_probe.dart';

/// Kotlin [BackgroundHealthCapabilityChannel] — PowerManager + Build.MANUFACTURER.
class AndroidPlatformCapabilityProbe extends PlatformCapabilityProbe {
  AndroidPlatformCapabilityProbe({
    MethodChannel? channel,
    bool Function()? isAndroidPlatform,
  }) : _channel = channel ?? _defaultChannel,
       _isAndroidPlatform = isAndroidPlatform ?? (() => Platform.isAndroid);

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.astraapp.astra_app/background_health_capability',
  );

  static const String _methodBatteryExempt = 'isIgnoringBatteryOptimizations';
  static const String _methodManufacturer = 'getDeviceManufacturer';

  final MethodChannel _channel;
  final bool Function() _isAndroidPlatform;

  @override
  Future<bool> isBatteryOptimizationExempt() async {
    if (!_isAndroidPlatform()) {
      return true;
    }
    try {
      final exempt = await _channel.invokeMethod<bool>(_methodBatteryExempt);
      return exempt ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> getDeviceManufacturer() async {
    if (!_isAndroidPlatform()) {
      return null;
    }
    try {
      final manufacturer = await _channel.invokeMethod<String>(
        _methodManufacturer,
      );
      if (manufacturer == null || manufacturer.isEmpty) {
        return null;
      }
      return manufacturer;
    } on PlatformException {
      return null;
    }
  }
}
