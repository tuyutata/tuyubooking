import 'package:flutter/material.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/lan_service/employee_access_controller.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class EmployeeAccessPage extends StatefulWidget {
  const EmployeeAccessPage({this.controller, super.key});

  final EmployeeAccessController? controller;

  @override
  State<EmployeeAccessPage> createState() => _EmployeeAccessPageState();
}

final class _EmployeeAccessPageState extends State<EmployeeAccessPage> {
  late final EmployeeAccessController _controller =
      widget.controller ?? EmployeeAccessController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.refresh();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final strings = AppLocalizations.of(context);
      final snapshot = _controller.snapshot;
      return Scaffold(
        appBar: AppBar(title: Text(strings.employeeAccessTitle)),
        body: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              strings.employeeAccessSubtitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 22),
            _StatusCard(snapshot: snapshot, busy: _controller.busy),
            if (_controller.error != null) ...[
              const SizedBox(height: 16),
              Text(
                _controller.error is NativeBridgeException
                    ? (_controller.error! as NativeBridgeException).localized(
                        Localizations.localeOf(context).languageCode,
                      )
                    : strings.employeeAccessOperationFailed,
                style: const TextStyle(color: Color(0xffa43d24)),
              ),
            ],
            if (snapshot?.status == NativeEmployeeGatewayStatus.ready) ...[
              const SizedBox(height: 24),
              _ConnectionDetails(snapshot: snapshot!),
            ],
            const SizedBox(height: 24),
            Text(strings.employeeAccessDiscoveryHint),
            const SizedBox(height: 12),
            Text(strings.employeeAccessSecurityHint),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('employee-access-toggle'),
              onPressed: _controller.busy
                  ? null
                  : snapshot?.enabled == true
                  ? _controller.disable
                  : _controller.enable,
              icon: Icon(
                snapshot?.enabled == true
                    ? Icons.link_off_rounded
                    : Icons.lan_outlined,
              ),
              label: Text(
                snapshot?.enabled == true
                    ? strings.disableEmployeeAccess
                    : strings.enableEmployeeAccess,
              ),
            ),
          ],
        ),
      );
    },
  );
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot, required this.busy});

  final EmployeeGatewaySnapshot? snapshot;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final status = busy
        ? strings.employeeGatewayStarting
        : switch (snapshot?.status) {
            NativeEmployeeGatewayStatus.disabled =>
              strings.employeeGatewayDisabled,
            NativeEmployeeGatewayStatus.starting =>
              strings.employeeGatewayStarting,
            NativeEmployeeGatewayStatus.ready => strings.employeeGatewayReady,
            NativeEmployeeGatewayStatus.failed => strings.employeeGatewayFailed,
            NativeEmployeeGatewayStatus.stopping =>
              strings.employeeGatewayStopping,
            null => strings.moduleStatusUnknown,
          };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.router_outlined),
        title: Text(strings.employeeAccessTitle),
        subtitle: Text(status),
      ),
    );
  }
}

final class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({required this.snapshot});

  final EmployeeGatewaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.employeeAccessAddress),
            SelectableText(snapshot.httpsOrigin),
            const SizedBox(height: 14),
            Text(strings.certificateFingerprint),
            SelectableText(snapshot.certificateFingerprint ?? ''),
            const SizedBox(height: 14),
            Text(strings.employeeAccessRoutes),
            ...snapshot.routes.map(
              (route) => SelectableText('${route.module}: ${route.path}'),
            ),
          ],
        ),
      ),
    );
  }
}
