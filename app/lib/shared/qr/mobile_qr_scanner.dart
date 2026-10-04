import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';

/// iOS and Android scanner. QR values stay in the current App process.
final class MobileQrScanner implements QrScanner {
  const MobileQrScanner();

  @override
  Future<String?> scan(
    BuildContext context, {
    required String title,
    required String instruction,
    required String unavailableMessage,
    required String cancelLabel,
  }) => Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MobileScannerPage(
        title: title,
        instruction: instruction,
        unavailableMessage: unavailableMessage,
        cancelLabel: cancelLabel,
      ),
    ),
  );
}

final class _MobileScannerPage extends StatefulWidget {
  const _MobileScannerPage({
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
  State<_MobileScannerPage> createState() => _MobileScannerPageState();
}

final class _MobileScannerPageState extends State<_MobileScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _resolved = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_resolved || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    _resolved = true;
    await _controller.stop();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: widget.cancelLabel,
        icon: const Icon(Icons.close_rounded),
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (!_failed)
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) {
              if (!_failed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _failed = true);
                });
              }
              return const ColoredBox(color: Colors.black);
            },
          )
        else
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  widget.unavailableMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        if (!_failed)
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                widget.instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
