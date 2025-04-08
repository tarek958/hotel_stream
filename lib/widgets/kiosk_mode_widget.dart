import 'package:flutter/material.dart';
import '../services/kiosk_service.dart';

/// A widget that wraps the entire app to provide kiosk mode functionality
class KioskModeWidget extends StatefulWidget {
  final Widget child;
  final bool autoEnableKiosk;
  final bool detectFallbackOnStartup;

  const KioskModeWidget({
    super.key,
    required this.child,
    this.autoEnableKiosk = true,
    this.detectFallbackOnStartup = false,
  });

  @override
  State<KioskModeWidget> createState() => _KioskModeWidgetState();
}

class _KioskModeWidgetState extends State<KioskModeWidget> {
  final KioskService _kioskService = KioskService();

  @override
  void initState() {
    super.initState();
    _initKioskMode();
  }

  Future<void> _initKioskMode() async {
    await _kioskService.init();

    // Always enable kiosk mode
    final result = await _kioskService.enableKioskMode();

    // If kiosk mode failed, try to use fallback mode
    if (!result) {
      await _kioskService.enableFallbackKioskMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Just return the child directly without any overlay controls
    return widget.child;
  }
}
