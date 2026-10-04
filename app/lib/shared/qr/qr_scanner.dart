import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_lite_camera/flutter_lite_camera.dart';
import 'package:zxing2/qrcode.dart';

abstract interface class QrScanner {
  Future<String?> scan(
    BuildContext context, {
    required String title,
    required String instruction,
    required String unavailableMessage,
    required String cancelLabel,
  });
}

typedef EmbeddedQrScanCallback = Future<void> Function(String rawValue);

/// Optional host-side scanner surface used when a QR exchange must remain in
/// one page. The camera is still owned by the scanner implementation and raw
/// frames never leave the current process.
abstract interface class EmbeddedQrScanner {
  Widget buildEmbedded({
    Key? key,
    required EmbeddedQrScanCallback onScanned,
    required String preparingMessage,
    String? preparingSecondaryMessage,
    required String scanningMessage,
    String? scanningSecondaryMessage,
    required String recognizedMessage,
    String? recognizedSecondaryMessage,
    required String unavailableMessage,
    String? unavailableSecondaryMessage,
  });
}

/// One camera implementation for macOS, Linux, and Windows. The plugin is
/// compiled into each platform package and exposes native camera frames only
/// to this process; QR payloads are never uploaded or sent over the LAN.
final class DesktopQrScanner implements QrScanner, EmbeddedQrScanner {
  const DesktopQrScanner();

  @override
  Widget buildEmbedded({
    Key? key,
    required EmbeddedQrScanCallback onScanned,
    required String preparingMessage,
    String? preparingSecondaryMessage,
    required String scanningMessage,
    String? scanningSecondaryMessage,
    required String recognizedMessage,
    String? recognizedSecondaryMessage,
    required String unavailableMessage,
    String? unavailableSecondaryMessage,
  }) => DesktopQrScannerPane(
    key: key,
    onScanned: onScanned,
    preparingMessage: preparingMessage,
    preparingSecondaryMessage: preparingSecondaryMessage,
    scanningMessage: scanningMessage,
    scanningSecondaryMessage: scanningSecondaryMessage,
    recognizedMessage: recognizedMessage,
    recognizedSecondaryMessage: recognizedSecondaryMessage,
    unavailableMessage: unavailableMessage,
    unavailableSecondaryMessage: unavailableSecondaryMessage,
  );

  @override
  Future<String?> scan(
    BuildContext context, {
    required String title,
    required String instruction,
    required String unavailableMessage,
    required String cancelLabel,
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ScannerDialog(
      title: title,
      instruction: instruction,
      unavailableMessage: unavailableMessage,
      cancelLabel: cancelLabel,
    ),
  );
}

final class _ScannerDialog extends StatefulWidget {
  const _ScannerDialog({
    required this.title,
    required this.instruction,
    required this.unavailableMessage,
    required this.cancelLabel,
  });

  final String title;
  final String instruction;
  final String unavailableMessage;
  final String cancelLabel;

  @override
  State<_ScannerDialog> createState() => _ScannerDialogState();
}

final class _ScannerDialogState extends State<_ScannerDialog> {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.instruction),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DesktopQrScannerPane(
                preparingMessage: widget.title,
                scanningMessage: widget.instruction,
                recognizedMessage: widget.title,
                unavailableMessage: widget.unavailableMessage,
                onScanned: (value) async {
                  if (mounted) Navigator.of(context).pop(value);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
    ],
  );
}

enum _DesktopQrScannerState { preparing, scanning, recognized, unavailable }

/// Reusable desktop camera surface shared by modal scans and the host
/// initialization page. It claims one QR value, stops the camera immediately,
/// and delegates TUYU parsing and sr25519 verification to the native boundary.
final class DesktopQrScannerPane extends StatefulWidget {
  const DesktopQrScannerPane({
    required this.onScanned,
    required this.preparingMessage,
    this.preparingSecondaryMessage,
    required this.scanningMessage,
    this.scanningSecondaryMessage,
    required this.recognizedMessage,
    this.recognizedSecondaryMessage,
    required this.unavailableMessage,
    this.unavailableSecondaryMessage,
    super.key,
  });

  final EmbeddedQrScanCallback onScanned;
  final String preparingMessage;
  final String? preparingSecondaryMessage;
  final String scanningMessage;
  final String? scanningSecondaryMessage;
  final String recognizedMessage;
  final String? recognizedSecondaryMessage;
  final String unavailableMessage;
  final String? unavailableSecondaryMessage;

  @override
  State<DesktopQrScannerPane> createState() => _DesktopQrScannerPaneState();
}

final class _DesktopQrScannerPaneState extends State<DesktopQrScannerPane> {
  final FlutterLiteCamera _camera = FlutterLiteCamera();
  Timer? _timer;
  int? _textureId;
  bool _decoding = false;
  bool _released = false;
  bool _resolved = false;
  _DesktopQrScannerState _state = _DesktopQrScannerState.preparing;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final devices = await _camera.getDeviceList();
      if (devices.isEmpty) throw StateError('No application camera available');
      await _camera.open(0);
      final textureId = await _camera.startPreview();
      if (!mounted) return;
      setState(() {
        _textureId = textureId;
        _state = _DesktopQrScannerState.scanning;
      });
      _timer = Timer.periodic(
        const Duration(milliseconds: 350),
        (_) => unawaited(_capture()),
      );
    } on Object {
      if (mounted) {
        setState(() => _state = _DesktopQrScannerState.unavailable);
      }
    }
  }

  Future<void> _capture() async {
    if (_decoding || _resolved || !mounted || _textureId == null) return;
    _decoding = true;
    try {
      final frame = await _camera.captureFrame();
      final data = frame['data'];
      final width = frame['width'];
      final height = frame['height'];
      if (data is! Uint8List || width is! int || height is! int) return;
      final decoded = await Isolate.run(
        () => decodeRgbQr(data, width: width, height: height),
      );
      if (decoded != null && mounted) {
        _resolved = true;
        _timer?.cancel();
        setState(() => _state = _DesktopQrScannerState.recognized);
        await _release();
        await widget.onScanned(decoded);
      }
    } on Object {
      // A frame without a complete QR code is expected while aiming.
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    if (_released) return;
    _released = true;
    if (_textureId != null) await _camera.stopPreview();
    await _camera.release();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_textureId != null && _state != _DesktopQrScannerState.unavailable)
          Texture(textureId: _textureId!),
        if (_state == _DesktopQrScannerState.preparing)
          const Center(child: CircularProgressIndicator()),
        if (_state == _DesktopQrScannerState.unavailable)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.unavailableMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (_state == _DesktopQrScannerState.recognized)
          const ColoredBox(color: Color(0xaa000000)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xaa000000),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_statusIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_secondaryStatusMessage case final secondary?)
                        Text(
                          secondary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xffd6e5e5),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  IconData get _statusIcon => switch (_state) {
    _DesktopQrScannerState.preparing => Icons.camera_alt_outlined,
    _DesktopQrScannerState.scanning => Icons.qr_code_scanner,
    _DesktopQrScannerState.recognized => Icons.verified_outlined,
    _DesktopQrScannerState.unavailable => Icons.videocam_off_outlined,
  };

  String get _statusMessage => switch (_state) {
    _DesktopQrScannerState.preparing => widget.preparingMessage,
    _DesktopQrScannerState.scanning => widget.scanningMessage,
    _DesktopQrScannerState.recognized => widget.recognizedMessage,
    _DesktopQrScannerState.unavailable => widget.unavailableMessage,
  };

  String? get _secondaryStatusMessage => switch (_state) {
    _DesktopQrScannerState.preparing => widget.preparingSecondaryMessage,
    _DesktopQrScannerState.scanning => widget.scanningSecondaryMessage,
    _DesktopQrScannerState.recognized => widget.recognizedSecondaryMessage,
    _DesktopQrScannerState.unavailable => widget.unavailableSecondaryMessage,
  };
}

String? decodeRgbQr(Uint8List rgb, {required int width, required int height}) {
  if (rgb.length != width * height * 3) return null;
  final pixels = Int32List(width * height);
  for (var index = 0; index < pixels.length; index++) {
    final offset = index * 3;
    pixels[index] =
        0xff000000 |
        (rgb[offset] << 16) |
        (rgb[offset + 1] << 8) |
        rgb[offset + 2];
  }
  try {
    final source = RGBLuminanceSource(width, height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } on Object {
    return null;
  }
}
