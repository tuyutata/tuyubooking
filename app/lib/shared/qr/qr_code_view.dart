import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

/// Renders protocol payloads locally. No network service or image asset is
/// involved, so the exact challenge bytes shown to the phone are preserved.
final class QrCodeView extends StatelessWidget {
  const QrCodeView({required this.data, this.size = 260, super.key});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _QrPainter(data)),
  );
}

final class _QrPainter extends CustomPainter {
  _QrPainter(String data) : code = Encoder.encode(data, ErrorCorrectionLevel.m);

  final QRCode code;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = code.matrix!;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    const quietZone = 4;
    final modules = matrix.width + quietZone * 2;
    final unit = size.shortestSide / modules;
    final paint = Paint()..color = const Color(0xff17130f);
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              (x + quietZone) * unit,
              (y + quietZone) * unit,
              unit + .2,
              unit + .2,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.code != code;
}
