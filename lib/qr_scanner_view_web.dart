// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class MobileScannerController {
  html.MediaStream? _stream;
  bool _active = false;

  bool get isActive => _active;

  void _attach(html.MediaStream stream) {
    _stream = stream;
    _active = true;
  }

  Future<void> start() async {
    _active = true;
  }

  Future<void> stop() async {
    _active = false;
  }

  Future<void> dispose() async {
    _active = false;
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
  }
}

class Barcode {
  final String? rawValue;
  const Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;
  const BarcodeCapture({required this.barcodes});
}

class QrScannerView extends StatefulWidget {
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
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  static int _counter = 0;
  late final String _viewId;
  late final html.VideoElement _video;
  late final html.CanvasElement _canvas;
  Timer? _scanTimer;
  bool _initialized = false;
  bool _errorOccurred = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'qr-scanner-web-${_counter++}';
    _video = html.VideoElement()
      ..autoplay = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    _canvas = html.CanvasElement();

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _video);
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final stream =
          await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment'},
      });
      _video.srcObject = stream;
      widget.controller._attach(stream);
      if (mounted) setState(() => _initialized = true);
      _scanTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _scanFrame(),
      );
    } catch (e, st) {
      if (mounted) setState(() => _errorOccurred = true);
      widget.onDetectError(e, st);
    }
  }

  void _scanFrame() {
    if (!widget.controller.isActive) return;
    if (_video.readyState < 2) return;

    final w = _video.videoWidth;
    final h = _video.videoHeight;
    if (w == 0 || h == 0) return;
    if (!js.context.hasProperty('jsQR')) return;

    _canvas.width = w;
    _canvas.height = h;
    final ctx = _canvas.getContext('2d') as html.CanvasRenderingContext2D;
    ctx.drawImage(_video, 0, 0);
    final imageData = ctx.getImageData(0, 0, w, h);

    final result = js.context.callMethod('jsQR', [
      imageData.data,
      w,
      h,
      js.JsObject.jsify({'inversionAttempts': 'dontInvert'}),
    ]);

    if (result != null) {
      final code = (result as js.JsObject)['data'] as String?;
      if (code != null && code.isNotEmpty) {
        widget.onDetect(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
      }
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    unawaited(widget.controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorOccurred) {
      return const Center(
        child: Text(
          '카메라를 열 수 없습니다',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    return HtmlElementView(viewType: _viewId);
  }
}
