import 'package:flutter/material.dart';
import 'package:tuyubooking/client/business_mode_selection.dart';
import 'package:tuyubooking/client/business_mode.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations_en.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations_zh.dart';

/// Multi-select setup shown after CitizenSdk reports a ready device wallet.
final class BusinessModeSelectionPage extends StatefulWidget {
  const BusinessModeSelectionPage({
    required this.selection,
    this.onCompleted,
    this.loadOnStart = true,
    super.key,
  });

  final BusinessModeSelection selection;
  final Future<void> Function(Set<BusinessMode> selected)? onCompleted;
  final bool loadOnStart;

  @override
  State<BusinessModeSelectionPage> createState() =>
      _BusinessModeSelectionPageState();
}

final class _BusinessModeSelectionPageState
    extends State<BusinessModeSelectionPage> {
  final _zh = AppLocalizationsZh();
  final _en = AppLocalizationsEn();

  BilingualCopy _copy(String zh, String en) => BilingualCopy(zh: zh, en: en);

  @override
  void initState() {
    super.initState();
    if (widget.loadOnStart) {
      widget.selection.load();
    }
  }

  Future<void> _save() async {
    if (!widget.selection.canContinue) {
      _showMessage(
        _copy(_zh.clientBusinessModeRequired, _en.clientBusinessModeRequired),
      );
      return;
    }
    try {
      await widget.selection.save();
      await widget.onCompleted?.call(widget.selection.selected);
    } on Object {
      if (!mounted) {
        return;
      }
      _showMessage(
        _copy(
          _zh.clientBusinessModeSaveFailed,
          _en.clientBusinessModeSaveFailed,
        ),
      );
    }
  }

  void _showMessage(BilingualCopy copy) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: BilingualText(copy)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primaryContainer.withValues(alpha: 0.38),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.selection,
            builder: (context, _) => _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BilingualText(
                _copy(_zh.clientBusinessModeTitle, _en.clientBusinessModeTitle),
                primaryStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              BilingualText(
                _copy(
                  _zh.clientBusinessModeSubtitle,
                  _en.clientBusinessModeSubtitle,
                ),
                primaryStyle: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: widget.selection.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 560 ? 2 : 1;
                          final cardWidth =
                              (constraints.maxWidth - (columns - 1) * 14) /
                              columns;
                          return SingleChildScrollView(
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: BusinessMode.values
                                  .map(
                                    (mode) => SizedBox(
                                      width: cardWidth,
                                      child: _ModeCard(
                                        mode: mode,
                                        copy: _modeCopy(mode),
                                        selected: widget.selection.selected
                                            .contains(mode),
                                        onTap: () =>
                                            widget.selection.toggle(mode),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('save-business-modes'),
                onPressed: widget.selection.canContinue ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: widget.selection.isSaving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : BilingualText(
                        _copy(
                          _zh.clientBusinessModeSave,
                          _en.clientBusinessModeSave,
                        ),
                        textAlign: TextAlign.center,
                        primaryStyle: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        secondaryStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BilingualCopy _modeCopy(BusinessMode mode) => switch (mode) {
    BusinessMode.hotel => _copy(
      _zh.clientBusinessModeHotel,
      _en.clientBusinessModeHotel,
    ),
    BusinessMode.restaurant => _copy(
      _zh.clientBusinessModeRestaurant,
      _en.clientBusinessModeRestaurant,
    ),
    BusinessMode.tour => _copy(
      _zh.clientBusinessModeTour,
      _en.clientBusinessModeTour,
    ),
    BusinessMode.ticket => _copy(
      _zh.clientBusinessModeTicket,
      _en.clientBusinessModeTicket,
    ),
  };
}

final class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.copy,
    required this.selected,
    required this.onTap,
  });

  final BusinessMode mode;
  final BilingualCopy copy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('business-mode-${mode.code}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(_iconFor(mode), size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: BilingualText(
                  copy,
                  primaryStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(BusinessMode mode) => switch (mode) {
    BusinessMode.hotel => Icons.hotel_rounded,
    BusinessMode.restaurant => Icons.restaurant_rounded,
    BusinessMode.tour => Icons.travel_explore_rounded,
    BusinessMode.ticket => Icons.confirmation_number_rounded,
  };
}
