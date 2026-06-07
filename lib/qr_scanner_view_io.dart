export 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScannerController, BarcodeCapture;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatelessWidget {
  const QrScannerView({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.onDetectError,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final void Function(Object, StackTrace) onDetectError;

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: controller,
      useAppLifecycleState: false,
      onDetect: onDetect,
      onDetectError: onDetectError,
    );
  }
}
