import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/hotel/hotel_front_desk_page.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/restaurant/restaurant_page.dart';
import 'package:tuyubooking/client/ticket/ticket_operations_page.dart';
import 'package:tuyubooking/client/tour/tour_operations_page.dart';

final class EmployeeSessionPage extends StatefulWidget {
  const EmployeeSessionPage({required this.session, super.key});

  final EmployeeSession session;

  @override
  State<EmployeeSessionPage> createState() => _EmployeeSessionPageState();
}

final class _EmployeeSessionPageState extends State<EmployeeSessionPage> {
  static const _success = BilingualCopy(
    zh: '员工账户登录成功',
    en: 'Employee account signed in',
  );
  static const _ready = BilingualCopy(
    zh: '该业务子系统的员工会话已经建立，后续业务页面将复用此原生账户权限。',
    en: 'The subsystem session is ready. Business screens will reuse these native account permissions.',
  );
  static const _signOut = BilingualCopy(zh: '退出登录', en: 'Sign out');
  bool _signingOut = false;

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  Future<void> _signOutEmployee() async {
    setState(() => _signingOut = true);
    try {
      await widget.session.signOut();
    } on Object {
      // Closing the local process session remains authoritative for this App.
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.module == EmployeeBusinessModule.hotel) {
      return HotelFrontDeskPage(
        session: widget.session,
        onSignOut: _signOutEmployee,
      );
    }
    if (widget.session.module == EmployeeBusinessModule.restaurant) {
      return RestaurantPage(
        session: widget.session,
        onSignOut: _signOutEmployee,
      );
    }
    if (widget.session.module == EmployeeBusinessModule.tour) {
      return TourOperationsPage(
        session: widget.session,
        onSignOut: _signOutEmployee,
      );
    }
    if (widget.session.module == EmployeeBusinessModule.ticket) {
      return TicketOperationsPage(
        session: widget.session,
        onSignOut: _signOutEmployee,
      );
    }
    return Scaffold(
      appBar: AppBar(title: BilingualText(widget.session.module.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      BilingualText(
                        _success,
                        textAlign: TextAlign.center,
                        primaryStyle: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.session.identity,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 18),
                      const BilingualText(_ready, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _signingOut ? null : _signOutEmployee,
                        icon: const Icon(Icons.logout_rounded),
                        label: const BilingualText(_signOut),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
