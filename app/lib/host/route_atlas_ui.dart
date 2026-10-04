import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';

/// Scoped visual tokens for the desktop route-atlas first-run experience.
abstract final class TuyuRouteAtlasPalette {
  static const ink = Color(0xff082b23);
  static const forest = Color(0xff123e32);
  static const leaf = Color(0xff2f6b52);
  static const eucalyptus = Color(0xffc7d2be);
  static const paper = Color(0xffeee9dc);
  static const ivory = Color(0xfff7f2e7);
  static const amber = Color(0xffd5a95d);
  static const muted = Color(0xff9db1a2);
  static const danger = Color(0xfff1a387);
}

/// Shared shell for administrator initialization and business-mode selection.
final class TuyuRouteAtlasShell extends StatelessWidget {
  const TuyuRouteAtlasShell({required this.child, this.activeStep, super.key});

  final Widget child;
  final int? activeStep;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TuyuRouteAtlasPalette.ink,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: CustomPaint(painter: TuyuAtlasBackgroundPainter()),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Row(
                        children: [
                          const TuyuAtlasBrand(compact: true),
                          if (activeStep != null) ...[
                            const SizedBox(width: 28),
                            Expanded(
                              child: TuyuRouteProgressRail(
                                activeStep: activeStep!,
                                horizontal: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(child: child),
                  ],
                );
              }
              return Row(
                children: [
                  Container(
                    width: 210,
                    padding: const EdgeInsets.fromLTRB(30, 28, 24, 28),
                    decoration: const BoxDecoration(
                      color: Color(0x26000000),
                      border: Border(
                        right: BorderSide(color: Color(0x35d5a95d)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TuyuAtlasBrand(),
                        if (activeStep != null) ...[
                          const Spacer(),
                          TuyuRouteProgressRail(activeStep: activeStep!),
                          const Spacer(),
                        ] else
                          const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Displays the canonical Tuyu asset without tinting, redrawing, or cropping.
final class TuyuAtlasBrand extends StatelessWidget {
  const TuyuAtlasBrand({this.compact = false, super.key});

  static const _brand = BilingualCopy(zh: '途遇商家端', en: 'TuyuBooking');

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 42 : 50,
        height: compact ? 42 : 50,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x80f7f2e7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset(
          'tuyu_logo.png',
          key: const ValueKey('route-atlas-brand-logo'),
          fit: BoxFit.contain,
          semanticLabel: _brand.primary(context),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: BilingualText(
          _brand,
          maxLines: 1,
          primaryStyle: TextStyle(
            color: TuyuRouteAtlasPalette.ivory,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          secondaryStyle: TextStyle(
            color: TuyuRouteAtlasPalette.amber,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
    ],
  );
}

final class TuyuRouteProgressRail extends StatelessWidget {
  const TuyuRouteProgressRail({
    required this.activeStep,
    this.horizontal = false,
    super.key,
  });

  static const _administrator = BilingualCopy(zh: '设置管理员', en: 'Administrator');
  static const _businessModes = BilingualCopy(zh: '经营模式', en: 'Business modes');

  final int activeStep;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final first = _AtlasStep(
      number: 1,
      label: _administrator,
      active: activeStep == 1,
    );
    final second = _AtlasStep(
      number: 2,
      label: _businessModes,
      active: activeStep == 2,
    );
    if (horizontal) {
      return Row(
        children: [
          first,
          const Expanded(child: _RouteLine(horizontal: true)),
          second,
        ],
      );
    }
    return SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          const Expanded(child: _RouteLine()),
          second,
        ],
      ),
    );
  }
}

final class _AtlasStep extends StatelessWidget {
  const _AtlasStep({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final BilingualCopy label;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    child: Row(
      key: ValueKey('route-atlas-step-$number'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: active ? 22 : 16,
          height: active ? 22 : 16,
          decoration: BoxDecoration(
            color: active
                ? TuyuRouteAtlasPalette.amber
                : TuyuRouteAtlasPalette.ink,
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? TuyuRouteAtlasPalette.amber
                  : TuyuRouteAtlasPalette.muted,
              width: 2,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x66d5a95d),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(
                color: active
                    ? TuyuRouteAtlasPalette.amber
                    : TuyuRouteAtlasPalette.muted,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            BilingualText(
              label,
              maxLines: 1,
              primaryStyle: TextStyle(
                color: active
                    ? TuyuRouteAtlasPalette.ivory
                    : TuyuRouteAtlasPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              secondaryStyle: TextStyle(
                color: active
                    ? TuyuRouteAtlasPalette.amber
                    : TuyuRouteAtlasPalette.muted,
                fontSize: 8,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

final class _RouteLine extends StatelessWidget {
  const _RouteLine({this.horizontal = false});

  final bool horizontal;

  @override
  Widget build(BuildContext context) => horizontal
      ? Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: const Color(0x66d5a95d),
        )
      : Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 1, color: const Color(0x66d5a95d)),
          ),
        );
}

/// Draws the option-2 grid, globe arc, contours, route, and waypoint nodes.
final class TuyuAtlasBackgroundPainter extends CustomPainter {
  const TuyuAtlasBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x0df7f2e7)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final contour = Paint()
      ..color = const Color(0x20d5a95d)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final center = Offset(size.width * 0.82, size.height * 0.72);
    for (var index = 0; index < 6; index += 1) {
      final inset = index * 28.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(index * 4, -index * 3),
          width: size.width * 0.48 - inset,
          height: size.height * 0.30 - inset * 0.45,
        ),
        contour,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.62, size.height * 0.04),
        radius: size.width * 0.32,
      ),
      0.15,
      2.8,
      false,
      Paint()
        ..color = const Color(0x22c7d2be)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.88)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.64,
        size.width * 0.52,
        size.height * 0.94,
        size.width * 0.70,
        size.height * 0.61,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.39,
        size.width * 0.91,
        size.height * 0.48,
        size.width * 1.04,
        size.height * 0.24,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0x38d5a95d)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final point in [
      Offset(size.width * 0.18, size.height * 0.88),
      Offset(size.width * 0.70, size.height * 0.61),
      Offset(size.width * 0.91, size.height * 0.43),
    ]) {
      canvas.drawCircle(point, 4, Paint()..color = const Color(0x99d5a95d));
      canvas.drawCircle(point, 9, contour);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Connects the four mode cards and highlights selected route segments.
final class TuyuBusinessRoutePainter extends CustomPainter {
  const TuyuBusinessRoutePainter({required this.selected});

  final List<bool> selected;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.27, size.height * 0.28),
      Offset(size.width * 0.73, size.height * 0.28),
      Offset(size.width * 0.27, size.height * 0.72),
      Offset(size.width * 0.73, size.height * 0.72),
    ];
    const order = [0, 1, 3, 2];
    final base = Paint()
      ..color = const Color(0x669db1a2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final active = Paint()
      ..color = TuyuRouteAtlasPalette.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var index = 0; index < order.length - 1; index += 1) {
      final fromIndex = order[index];
      final toIndex = order[index + 1];
      final from = points[fromIndex];
      final to = points[toIndex];
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx + (to.dx - from.dx) * 0.42,
          from.dy,
          from.dx + (to.dx - from.dx) * 0.58,
          to.dy,
          to.dx,
          to.dy,
        );
      canvas.drawPath(path, base);
      if (selected[fromIndex] && selected[toIndex]) {
        canvas.drawPath(path, active);
      }
    }

    for (var index = 0; index < points.length; index += 1) {
      final color = selected[index]
          ? TuyuRouteAtlasPalette.amber
          : TuyuRouteAtlasPalette.muted;
      canvas.drawCircle(points[index], 8, Paint()..color = color);
      canvas.drawCircle(
        points[index],
        13,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TuyuBusinessRoutePainter oldDelegate) =>
      !listEquals(oldDelegate.selected, selected);
}
