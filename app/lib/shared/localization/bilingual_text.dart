import 'package:flutter/material.dart';

/// Chinese and English copy displayed together across every TuyuBooking mode.
final class BilingualCopy {
  const BilingualCopy({required this.zh, required this.en});

  final String zh;
  final String en;

  bool chineseIsPrimary(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('zh');

  String primary(BuildContext context) => chineseIsPrimary(context) ? zh : en;
  String secondary(BuildContext context) => chineseIsPrimary(context) ? en : zh;
}

/// Shows the device language prominently and the other language as assistance.
final class BilingualText extends StatelessWidget {
  const BilingualText(
    this.copy, {
    this.primaryStyle,
    this.secondaryStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    super.key,
  });

  final BilingualCopy copy;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final resolvedPrimary = primaryStyle ?? DefaultTextStyle.of(context).style;
    final primarySize = resolvedPrimary.fontSize ?? 14;
    final resolvedSecondary =
        secondaryStyle ??
        resolvedPrimary.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: (primarySize * 0.7).clamp(10, 13).toDouble(),
          fontWeight: FontWeight.w400,
        );
    final alignment = switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          copy.primary(context),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          textAlign: textAlign,
          style: resolvedPrimary,
        ),
        const SizedBox(height: 2),
        Text(
          copy.secondary(context),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          textAlign: textAlign,
          style: resolvedSecondary,
        ),
      ],
    );
  }
}
