import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';
import 'package:tuyubooking/host/route_atlas_ui.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';

final class BusinessModuleSelectionPage extends StatefulWidget {
  const BusinessModuleSelectionPage({this.initialization = false, super.key});

  final bool initialization;

  @override
  State<BusinessModuleSelectionPage> createState() =>
      _BusinessModuleSelectionPageState();
}

final class _BusinessModuleSelectionPageState
    extends State<BusinessModuleSelectionPage> {
  static const _eyebrow = BilingualCopy(
    zh: '02 / 经营模式',
    en: '02 / BUSINESS MODES',
  );
  static const _title = BilingualCopy(
    zh: '选择经营模式',
    en: 'Choose business modes',
  );
  static const _subtitle = BilingualCopy(
    zh: '可多选，稍后可启用或停用',
    en: 'Select one or more',
  );
  static const _continue = BilingualCopy(zh: '开始使用', en: 'Continue');
  static const _back = BilingualCopy(zh: '返回', en: 'Back');
  static const _saveLabel = BilingualCopy(zh: '保存并启用', en: 'Save and enable');
  static const _required = BilingualCopy(
    zh: '至少选择一个经营模式。',
    en: 'Choose at least one business mode.',
  );
  static const _saveFailed = BilingualCopy(
    zh: '经营模式配置保存失败。',
    en: 'The business mode configuration could not be saved.',
  );

  Set<MerchantSubsystem>? _selection;
  Object? _error;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<RuntimeController>();
    _selection ??= runtime.enabledModules.toSet();
    final modules = <_BusinessModePresentation>[
      const _BusinessModePresentation(
        subsystem: MerchantSubsystem.hotel,
        label: BilingualCopy(zh: '酒店', en: 'Hotel'),
        icon: Icons.local_hotel_outlined,
      ),
      const _BusinessModePresentation(
        subsystem: MerchantSubsystem.restaurant,
        label: BilingualCopy(zh: '餐厅', en: 'Restaurant'),
        icon: Icons.room_service_outlined,
      ),
      const _BusinessModePresentation(
        subsystem: MerchantSubsystem.tour,
        label: BilingualCopy(zh: '旅行团', en: 'Tours'),
        icon: Icons.alt_route_rounded,
      ),
      const _BusinessModePresentation(
        subsystem: MerchantSubsystem.ticket,
        label: BilingualCopy(zh: '票务', en: 'Ticketing'),
        icon: Icons.confirmation_number_outlined,
      ),
    ];
    final selectedFlags = modules
        .map((module) => _selection!.contains(module.subsystem))
        .toList(growable: false);
    return PopScope(
      canPop: !widget.initialization,
      child: TuyuRouteAtlasShell(
        activeStep: 2,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BilingualText(
                    _eyebrow,
                    textAlign: TextAlign.center,
                    primaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                    secondaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.muted,
                      fontSize: 9,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BilingualText(
                    _title,
                    textAlign: TextAlign.center,
                    primaryStyle: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(
                          color: TuyuRouteAtlasPalette.ivory,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                    secondaryStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: TuyuRouteAtlasPalette.amber,
                          letterSpacing: 1,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const BilingualText(
                    _subtitle,
                    textAlign: TextAlign.center,
                    primaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.ivory,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    secondaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const padding = 24.0;
                      const spacing = 28.0;
                      final canvasHeight = constraints.maxWidth < 680
                          ? 620.0
                          : 560.0;
                      final cellWidth =
                          (constraints.maxWidth - padding * 2 - spacing) / 2;
                      final cellHeight =
                          (canvasHeight - padding * 2 - spacing) / 2;
                      return SizedBox(
                        height: canvasHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: TuyuBusinessRoutePainter(
                                selected: selectedFlags,
                              ),
                            ),
                            GridView.builder(
                              padding: const EdgeInsets.all(padding),
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio: cellWidth / cellHeight,
                                  ),
                              itemCount: modules.length,
                              itemBuilder: (context, index) {
                                final module = modules[index];
                                return _BusinessModeCard(
                                  key: ValueKey(
                                    'select-${module.subsystem.name}',
                                  ),
                                  presentation: module,
                                  selected: selectedFlags[index],
                                  enabled: !runtime.isConfiguringModules,
                                  onPressed: () => setState(() {
                                    if (selectedFlags[index]) {
                                      _selection!.remove(module.subsystem);
                                    } else {
                                      _selection!.add(module.subsystem);
                                    }
                                    _error = null;
                                  }),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_selection!.isEmpty || _error != null) ...[
                    const SizedBox(height: 10),
                    BilingualText(
                      _selection!.isEmpty ? _required : _saveFailed,
                      key: const ValueKey('business-module-selection-error'),
                      textAlign: TextAlign.center,
                      primaryStyle: const TextStyle(
                        color: TuyuRouteAtlasPalette.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      secondaryStyle: const TextStyle(
                        color: TuyuRouteAtlasPalette.danger,
                        fontSize: 9,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _SelectionActionBar(
                    selectedCount: _selection!.length,
                    initialization: widget.initialization,
                    busy: runtime.isConfiguringModules,
                    onBack: () => Navigator.of(context).pop(),
                    onSave: _selection!.isEmpty || runtime.isConfiguringModules
                        ? null
                        : () => _save(runtime),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(RuntimeController runtime) async {
    try {
      await runtime.configureBusinessModules(_selection!);
      if (mounted && !widget.initialization) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }
}

final class _BusinessModePresentation {
  const _BusinessModePresentation({
    required this.subsystem,
    required this.label,
    required this.icon,
  });

  final MerchantSubsystem subsystem;
  final BilingualCopy label;
  final IconData icon;
}

final class _BusinessModeCard extends StatelessWidget {
  const _BusinessModeCard({
    required this.presentation,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final _BusinessModePresentation presentation;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    enabled: enabled,
    label: presentation.label.primary(context),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? TuyuRouteAtlasPalette.eucalyptus
            : TuyuRouteAtlasPalette.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? TuyuRouteAtlasPalette.amber
              : const Color(0x998aa091),
          width: selected ? 2.5 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        presentation.icon,
                        size: 54,
                        color: TuyuRouteAtlasPalette.ink,
                      ),
                      const SizedBox(height: 16),
                      BilingualText(
                        presentation.label,
                        textAlign: TextAlign.center,
                        primaryStyle: const TextStyle(
                          color: TuyuRouteAtlasPalette.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        secondaryStyle: TextStyle(
                          color: TuyuRouteAtlasPalette.ink.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? TuyuRouteAtlasPalette.amber
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? TuyuRouteAtlasPalette.amber
                            : TuyuRouteAtlasPalette.leaf,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: TuyuRouteAtlasPalette.ink,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.initialization,
    required this.busy,
    required this.onBack,
    required this.onSave,
  });

  final int selectedCount;
  final bool initialization;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final count = BilingualCopy(
      zh: '已选择 $selectedCount 项',
      en: '$selectedCount selected',
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe6123e32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55d5a95d)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.group_work_outlined,
              color: TuyuRouteAtlasPalette.amber,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BilingualText(
                count,
                key: const ValueKey('selected-business-module-count'),
                primaryStyle: const TextStyle(
                  color: TuyuRouteAtlasPalette.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                secondaryStyle: const TextStyle(
                  color: TuyuRouteAtlasPalette.muted,
                  fontSize: 9,
                ),
              ),
            ),
            if (!initialization) ...[
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TuyuRouteAtlasPalette.ivory,
                  side: const BorderSide(color: Color(0x66c7d2be)),
                  minimumSize: const Size(118, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const BilingualText(
                  _BusinessModuleSelectionPageState._back,
                  textAlign: TextAlign.center,
                  primaryStyle: TextStyle(
                    color: TuyuRouteAtlasPalette.ivory,
                    fontWeight: FontWeight.w700,
                  ),
                  secondaryStyle: TextStyle(
                    color: TuyuRouteAtlasPalette.muted,
                    fontSize: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            FilledButton(
              key: const ValueKey('save-business-modules'),
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: TuyuRouteAtlasPalette.amber,
                foregroundColor: TuyuRouteAtlasPalette.ink,
                disabledBackgroundColor: const Color(0x667b806f),
                minimumSize: const Size(172, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TuyuRouteAtlasPalette.ink,
                      ),
                    )
                  : BilingualText(
                      initialization
                          ? _BusinessModuleSelectionPageState._continue
                          : _BusinessModuleSelectionPageState._saveLabel,
                      textAlign: TextAlign.center,
                      primaryStyle: const TextStyle(
                        color: TuyuRouteAtlasPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                      secondaryStyle: const TextStyle(
                        color: TuyuRouteAtlasPalette.forest,
                        fontSize: 8,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
