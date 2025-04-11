import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_lock_task/flutter_lock_task.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A service that handles kiosk mode across the entire app
class KioskService {
  static final KioskService _instance = KioskService._internal();

  factory KioskService() => _instance;

  KioskService._internal() {
    _setupChannels();
  }

  final FlutterLockTask _lockTask = FlutterLockTask();
  bool _isKioskModeEnabled = false;
  bool _isInFallbackMode = false;

  // Platform channel for native communication
  static const MethodChannel _kioskChannel =
      MethodChannel('com.hotelstream/kiosk');

  void _setupChannels() {
    _kioskChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'setFallbackMode':
          _isInFallbackMode = call.arguments as bool;
          _kioskModeController.add(_isKioskModeEnabled);
          break;
        default:
          break;
      }
    });
  }

  // For tracking kiosk mode state
  final StreamController<bool> _kioskModeController =
      StreamController<bool>.broadcast();
  Stream<bool> get kioskModeStream => _kioskModeController.stream;

  bool get isKioskModeEnabled => _isKioskModeEnabled;

  /// Get whether the app is in fallback kiosk mode
  bool get isInFallbackMode => _isInFallbackMode;

  // // List of allowed logical keys - navigation keys
  // final List<int> allowedKeyIds = [
  //   LogicalKeyboardKey.arrowUp.keyId,
  //   LogicalKeyboardKey.arrowDown.keyId,
  //   LogicalKeyboardKey.arrowLeft.keyId,
  //   LogicalKeyboardKey.arrowRight.keyId,
  //   LogicalKeyboardKey.enter.keyId,
  //   LogicalKeyboardKey.select.keyId,
  // ];

  /// Initialize kiosk mode service - call this in main.dart or app start
  Future<void> init() async {
    // Check if already in lock task mode
    await checkKioskModeStatus();

    // Set system UI mode to immersive sticky
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    // Set preferred orientations to landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Register global key handler
    ServicesBinding.instance.keyboard.addHandler(_interceptKeys);
  }

  /// Start kiosk mode using flutter_lock_task
  Future<bool> enableKioskMode() async {
    try {
      bool result = await _lockTask.startLockTask();
      _isKioskModeEnabled = result;

      if (!result) {
        // If lock task failed, use fallback method
        await enableFallbackKioskMode();
        _isKioskModeEnabled =
            true; // We're still considering kiosk mode enabled
        _isInFallbackMode = true;
      } else {
        _isInFallbackMode = false;
      }

      _kioskModeController.add(_isKioskModeEnabled);

      // Enable immersive mode regardless of lock task status
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );

      return _isKioskModeEnabled;
    } catch (e) {
      await enableFallbackKioskMode();
      return _isInFallbackMode;
    }
  }

  /// Enable fallback kiosk mode without device owner
  Future<bool> enableFallbackKioskMode() async {
    try {
      // Enable immersive mode
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );

      // Set preferred orientations to landscape
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Tell native layer to use fallback mode
      try {
        await _kioskChannel.invokeMethod('enableFallbackKioskMode');
      } catch (e) {
        // Ignore errors
      }

      _isInFallbackMode = true;
      _kioskModeController.add(true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop kiosk mode
  Future<bool> disableKioskMode() async {
    try {
      bool result = true;

      if (!_isInFallbackMode) {
        // Only try to stop lock task if we were in real lock task mode
        result = await _lockTask.stopLockTask();
      }

      _isKioskModeEnabled = !result;
      _isInFallbackMode = false;
      _kioskModeController.add(!result);

      if (result) {
        // Restore system UI
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }

      return result;
    } catch (e) {
      return false;
    }
  }

  /// Check if device is in kiosk mode
  Future<bool> checkKioskModeStatus() async {
    try {
      bool result = await _lockTask.isInLockTaskMode();
      _isKioskModeEnabled = result;
      _kioskModeController.add(result);
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Set up device owner app (requires adb or root)
  Future<bool> setDeviceOwner() async {
    try {
      bool result = await _lockTask.setDeviceOwnerApp();
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Get package name for ADB setup
  Future<String> getPackageName() async {
    try {
      String? packageName = await _lockTask.getPackageName();
      final safePackageName = packageName ?? 'Unknown';
      return safePackageName;
    } catch (e) {
      return '';
    }
  }

  /// Global key interceptor - ONLY blocks specific content app keys
  bool _interceptKeys(KeyEvent event) {
    final keyId = event.logicalKey.keyId;

    // IMPORTANT: Only block specific vendor-specific keys like Netflix
    // All other keys should be allowed to pass through to the active screen
    if (keyId == 0x1100000fde || // Netflix key
        keyId == 0x00000010000009c5 || // Another Netflix key ID
        keyId == 0x1000080E9 || // YouTube key
        keyId == 0x10000834D) {
      // Prime Video key
      print('BLOCKED content app key: $keyId');
      return true; // Block only content app keys
    }

    // Let all other keys pass through to the focused elements
    // This ensures that navigation works correctly within each screen
    return false; // Don't intercept normal key navigation
  }

  /// Clean up resources
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_interceptKeys);
    _kioskModeController.close();
  }

  Future<bool> isLocalStorageAvailable() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.existsSync();
    } catch (e) {
      print('Error checking local storage: $e');
      return false;
    }
  }
}
