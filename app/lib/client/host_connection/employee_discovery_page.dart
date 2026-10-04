import 'package:flutter/material.dart';
import 'package:tuyubooking/client/business_mode.dart';
import 'package:tuyubooking/client/employee_access/employee_module_page.dart';
import 'package:tuyubooking/client/host_connection/employee_discovery_controller.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';

final class EmployeeDiscoveryPage extends StatefulWidget {
  const EmployeeDiscoveryPage({
    required this.selectedModes,
    this.controller,
    super.key,
  });

  final Set<BusinessMode> selectedModes;
  final EmployeeDiscoveryController? controller;

  @override
  State<EmployeeDiscoveryPage> createState() => _EmployeeDiscoveryPageState();
}

final class _EmployeeDiscoveryPageState extends State<EmployeeDiscoveryPage> {
  static const _appTitle = BilingualCopy(
    zh: '途遇商家员工端',
    en: 'TuyuBooking Staff',
  );
  static const _title = BilingualCopy(
    zh: '正在连接商家主机',
    en: 'Connecting to your merchant host',
  );
  static const _subtitle = BilingualCopy(
    zh: '分机将直接连接初始化时保存的固定主机地址。',
    en: 'This client connects directly to the fixed host address saved during initialization.',
  );
  static const _failed = BilingualCopy(
    zh: '无法连接商家主机，请检查局域网和主机运行状态。',
    en: 'The merchant host could not be reached. Check the local network and host status.',
  );
  static const _retry = BilingualCopy(zh: '重新连接', en: 'Connect again');

  late final EmployeeDiscoveryController _controller =
      widget.controller ?? EmployeeDiscoveryController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.start();
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
      final profile = _controller.profile;
      if (profile != null) {
        return EmployeeModulePage(
          profile: profile,
          selectedModes: widget.selectedModes,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const BilingualText(_appTitle)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.lan_outlined, size: 70),
                  const SizedBox(height: 18),
                  BilingualText(
                    _title,
                    textAlign: TextAlign.center,
                    primaryStyle: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const BilingualText(_subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  if (_controller.status ==
                          EmployeeDiscoveryStatus.initializing ||
                      _controller.status == EmployeeDiscoveryStatus.connecting)
                    const Center(child: CircularProgressIndicator()),
                  if (_controller.status == EmployeeDiscoveryStatus.failed) ...[
                    const BilingualText(
                      _failed,
                      textAlign: TextAlign.center,
                      primaryStyle: TextStyle(color: Color(0xffa43d24)),
                      secondaryStyle: TextStyle(
                        color: Color(0xffa43d24),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed:
                        _controller.status ==
                                EmployeeDiscoveryStatus.initializing ||
                            _controller.status ==
                                EmployeeDiscoveryStatus.connecting
                        ? null
                        : _controller.start,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const BilingualText(_retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
