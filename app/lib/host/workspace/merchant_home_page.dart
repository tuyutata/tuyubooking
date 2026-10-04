import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/runtime/external_url_launcher.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';
import 'package:tuyubooking/host/administrators/administrator_management_page.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';
import 'package:tuyubooking/host/infrastructure/lan_service/employee_access_page.dart';
import 'package:tuyubooking/host/business_module_selection_page.dart';
import 'package:tuyubooking/host/workspace/hotel_page.dart';
import 'package:tuyubooking/host/workspace/restaurant_page.dart';
import 'package:tuyubooking/host/workspace/ticket_page.dart';
import 'package:tuyubooking/host/workspace/tour_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class MerchantHomePage extends StatelessWidget {
  const MerchantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final session = context.watch<AuthController>().nativeSession!;
    final enabledModules = context.watch<RuntimeController>().enabledModules;
    final modules = <_Module>[
      _Module(
        MerchantSubsystem.hotel,
        strings.hotel,
        strings.hotelSubtitle,
        Icons.hotel_outlined,
        const Color(0xffa43d24),
        const HotelPage(),
      ),
      _Module(
        MerchantSubsystem.restaurant,
        strings.restaurant,
        strings.restaurantSubtitle,
        Icons.restaurant_outlined,
        const Color(0xff146c72),
        const RestaurantPage(),
      ),
      _Module(
        MerchantSubsystem.tour,
        strings.tour,
        strings.tourSubtitle,
        Icons.route_outlined,
        const Color(0xff496a3f),
        const TourPage(),
      ),
      _Module(
        MerchantSubsystem.ticket,
        strings.ticket,
        strings.ticketSubtitle,
        Icons.confirmation_number_outlined,
        const Color(0xff9a6b20),
        const TicketPage(),
      ),
    ].where((module) => enabledModules.contains(module.id)).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            title: Text(strings.merchantConsole),
            actions: [
              IconButton(
                key: const ValueKey('business-module-management'),
                tooltip: strings.manageBusinessModules,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BusinessModuleSelectionPage(),
                  ),
                ),
                icon: const Icon(Icons.widgets_outlined),
              ),
              IconButton(
                key: const ValueKey('employee-access'),
                tooltip: strings.employeeAccessTooltip,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmployeeAccessPage(),
                  ),
                ),
                icon: const Icon(Icons.lan_outlined),
              ),
              IconButton(
                key: const ValueKey('administrator-management'),
                tooltip: strings.administratorManagement,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdministratorManagementPage(),
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Center(
                  child: Text(
                    session.administratorName?.isNotEmpty == true
                        ? session.administratorName!
                        : session.publicKeyFingerprint.substring(0, 12),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  strings.homeHeadline,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.homeSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 920
                        ? (constraints.maxWidth - 18) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: modules
                          .map(
                            (module) => SizedBox(
                              width: width,
                              child: _ModuleCard(module: module),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _Module {
  const _Module(
    this.id,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.page,
  );
  final MerchantSubsystem id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
}

final class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});
  final _Module module;

  Future<void> _open(BuildContext context) async {
    if (module.id == MerchantSubsystem.hotel ||
        module.id == MerchantSubsystem.restaurant ||
        module.id == MerchantSubsystem.tour ||
        module.id == MerchantSubsystem.ticket) {
      final controller = context.read<AuthController>();
      final origin = context.read<RuntimeController>().moduleOrigin(module.id);
      if (origin == null) {
        throw StateError('The HTTPS business runtime is not ready');
      }
      final assertion = await controller.createAdministratorAssertion();
      final moduleOrigin = Uri.parse(origin);
      final fragment = <String, String>{'assertion': assertion.token};
      if (module.id == MerchantSubsystem.hotel ||
          module.id == MerchantSubsystem.restaurant) {
        fragment['target'] = module.id == MerchantSubsystem.hotel
            ? 'kamra'
            : 'ury';
      }
      final launchUri = moduleOrigin.replace(
        path: '/tuyu_admin',
        query: null,
        fragment: Uri(queryParameters: fragment).query,
      );
      await const ExternalUrlLauncher().open(launchUri.toString());
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => module.page));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final runtime = context.watch<RuntimeController>();
    final state = runtime.moduleState(module.id);
    final available =
        state?.status == NativeModuleRuntimeStatus.ready &&
        state?.httpsOrigin != null;
    final restarting = runtime.isRestarting(module.id);
    final canRestart =
        !restarting &&
        state != null &&
        const {
          NativeModuleRuntimeStatus.degraded,
          NativeModuleRuntimeStatus.failed,
          NativeModuleRuntimeStatus.stopped,
        }.contains(state.status);
    return Material(
      color: const Color(0xfffffbf2),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('module-${module.id.name}'),
        onTap: available ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(module.icon, size: 34, color: module.color),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(module.subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _RuntimeStatusBadge(
                    status: state?.status,
                    restarting: restarting,
                  ),
                  if (canRestart) ...[
                    const SizedBox(height: 8),
                    IconButton(
                      key: ValueKey('restart-${module.id.name}'),
                      tooltip: strings.restartModule,
                      onPressed: () => runtime.restartModule(module.id),
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                  ] else if (available) ...[
                    const SizedBox(height: 8),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _RuntimeStatusBadge extends StatelessWidget {
  const _RuntimeStatusBadge({required this.status, required this.restarting});

  final NativeModuleRuntimeStatus? status;
  final bool restarting;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final effectiveStatus = restarting
        ? NativeModuleRuntimeStatus.starting
        : status;
    final label = switch (effectiveStatus) {
      NativeModuleRuntimeStatus.disabled => strings.moduleStatusDisabled,
      NativeModuleRuntimeStatus.payloadMissing => strings.moduleStatusMissing,
      NativeModuleRuntimeStatus.installed => strings.moduleStatusInstalled,
      NativeModuleRuntimeStatus.starting => strings.moduleStatusStarting,
      NativeModuleRuntimeStatus.ready => strings.moduleStatusReady,
      NativeModuleRuntimeStatus.degraded => strings.moduleStatusDegraded,
      NativeModuleRuntimeStatus.failed => strings.moduleStatusFailed,
      NativeModuleRuntimeStatus.stopping => strings.moduleStatusStopping,
      NativeModuleRuntimeStatus.stopped => strings.moduleStatusStopped,
      null => strings.moduleStatusUnknown,
    };
    final color = switch (effectiveStatus) {
      NativeModuleRuntimeStatus.ready => const Color(0xff39704c),
      NativeModuleRuntimeStatus.starting ||
      NativeModuleRuntimeStatus.installed ||
      NativeModuleRuntimeStatus.stopping => const Color(0xff9a6b20),
      NativeModuleRuntimeStatus.disabled => const Color(0xff6d6a65),
      _ => const Color(0xffa43d24),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
