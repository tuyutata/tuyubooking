import 'package:flutter/material.dart';
import 'package:tuyubooking/client/business_mode.dart';
import 'package:tuyubooking/client/employee_access/employee_login_page.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';

final class EmployeeModulePage extends StatelessWidget {
  const EmployeeModulePage({
    required this.profile,
    required this.selectedModes,
    super.key,
  });

  static const _account = BilingualCopy(
    zh: '使用该业务子系统原有的员工账户登录。',
    en: 'Sign in with the existing employee account for this subsystem.',
  );

  final EmployeeHostProfile profile;
  final Set<BusinessMode> selectedModes;

  bool _selected(EmployeeBusinessModule module) => switch (module) {
    EmployeeBusinessModule.hotel => selectedModes.contains(BusinessMode.hotel),
    EmployeeBusinessModule.restaurant => selectedModes.contains(
      BusinessMode.restaurant,
    ),
    EmployeeBusinessModule.tour => selectedModes.contains(BusinessMode.tour),
    EmployeeBusinessModule.ticket => selectedModes.contains(
      BusinessMode.ticket,
    ),
  };

  IconData _icon(EmployeeBusinessModule module) => switch (module) {
    EmployeeBusinessModule.hotel => Icons.hotel_outlined,
    EmployeeBusinessModule.restaurant => Icons.restaurant_outlined,
    EmployeeBusinessModule.tour => Icons.route_outlined,
    EmployeeBusinessModule.ticket => Icons.confirmation_number_outlined,
  };

  @override
  Widget build(BuildContext context) {
    // A module is visible only when both the employee selected it on this
    // client and the connected host currently exposes its HTTPS route.
    final modules = profile.routes
        .map(EmployeeBusinessModule.fromRoute)
        .whereType<EmployeeBusinessModule>()
        .where(_selected)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(profile.merchantName)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 2 : 1;
          return GridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 2.5 : 2.2,
            children: modules
                .map((module) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EmployeeLoginPage(
                            profile: profile,
                            module: module,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(_icon(module), size: 38),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BilingualText(
                                    module.title,
                                    primaryStyle: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const BilingualText(_account),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}
