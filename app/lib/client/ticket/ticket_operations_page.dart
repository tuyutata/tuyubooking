import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/qr/mobile_qr_scanner.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/ticket/ticket_attendee_page.dart';
import 'package:tuyubooking/client/ticket/ticket_controller.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';
import 'package:tuyubooking/client/ticket/ticket_repository.dart';

final class TicketOperationsPage extends StatefulWidget {
  const TicketOperationsPage({
    required this.session,
    required this.onSignOut,
    super.key,
  });

  final EmployeeSession session;
  final Future<void> Function() onSignOut;

  @override
  State<TicketOperationsPage> createState() => _TicketOperationsPageState();
}

final class _TicketOperationsPageState extends State<TicketOperationsPage> {
  static const _title = BilingualCopy(zh: '票务核销', en: 'Ticket check-in');
  static const _event = BilingualCopy(zh: '活动', en: 'Event');
  static const _registered = BilingualCopy(
    zh: '已登记参与者',
    en: 'Registered attendees',
  );
  static const _checkedIn = BilingualCopy(zh: '已签到', en: 'Checked in');
  static const _search = BilingualCopy(
    zh: '姓名、邮箱或票券编号',
    en: 'Name, email, or ticket ID',
  );
  static const _searchAction = BilingualCopy(zh: '查询', en: 'Search');
  static const _scan = BilingualCopy(zh: '扫描票券', en: 'Scan ticket');
  static const _scanInstruction = BilingualCopy(
    zh: '将 Hi.Events 票券二维码放入取景框',
    en: 'Place the Hi.Events ticket QR code inside the frame',
  );
  static const _cameraUnavailable = BilingualCopy(
    zh: '无法使用摄像头，请检查权限或改用手工查询',
    en: 'Camera unavailable. Check permission or use manual search',
  );
  static const _cancel = BilingualCopy(zh: '取消', en: 'Cancel');
  static const _emptyEvents = BilingualCopy(
    zh: '当前账户没有可管理的活动',
    en: 'No manageable events',
  );
  static const _emptyAttendees = BilingualCopy(
    zh: '没有符合条件的参与者',
    en: 'No matching attendees',
  );
  static const _loadMore = BilingualCopy(zh: '加载更多', en: 'Load more');
  static const _failed = BilingualCopy(
    zh: '票务服务暂时不可用',
    en: 'Ticketing is unavailable',
  );
  static const _retry = BilingualCopy(zh: '重试', en: 'Retry');
  static const _signOut = BilingualCopy(zh: '退出登录', en: 'Sign out');
  static const _checked = BilingualCopy(zh: '已签到', en: 'Checked in');
  static const _notChecked = BilingualCopy(zh: '未签到', en: 'Not checked in');

  late final TicketController _controller;
  late final QrScanner _scanner;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanner = Platform.isIOS || Platform.isAndroid
        ? const MobileQrScanner()
        : const DesktopQrScanner();
    _controller = TicketController(TicketRepository(widget.session));
    _controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const BilingualText(_title),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 720)
            Center(child: Text(widget.session.identity)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: _signOut.primary(context),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _body()),
      floatingActionButton:
          _controller.event == null || _controller.status == TicketStatus.failed
          ? null
          : FloatingActionButton.extended(
              onPressed: _controller.isActing ? null : _scanTicket,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const BilingualText(_scan),
            ),
    ),
  );

  Widget _body() {
    if (_controller.status == TicketStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.status == TicketStatus.failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BilingualText(_failed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _controller.initialize,
              child: const BilingualText(_retry),
            ),
          ],
        ),
      );
    }
    if (_controller.events.isEmpty || _controller.event == null) {
      return const Center(child: BilingualText(_emptyEvents));
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          _eventSelector(),
          const SizedBox(height: 14),
          _summary(),
          const SizedBox(height: 14),
          _searchBar(),
          const SizedBox(height: 14),
          if (_controller.attendees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: BilingualText(_emptyAttendees)),
            )
          else
            ..._controller.attendees.map(_attendeeCard),
          if (_controller.canLoadMore)
            OutlinedButton(
              onPressed: _controller.status == TicketStatus.loadingMore
                  ? null
                  : _controller.loadMore,
              child: _controller.status == TicketStatus.loadingMore
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const BilingualText(_loadMore),
            ),
        ],
      ),
    );
  }

  Widget _eventSelector() => DropdownButtonFormField<String>(
    initialValue: _controller.event!.id,
    isExpanded: true,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.event_outlined),
      label: BilingualText(_event),
    ),
    items: _controller.events
        .map(
          (event) => DropdownMenuItem(
            value: event.id,
            child: Text(event.title, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: _controller.isActing
        ? null
        : (value) {
            if (value != null) {
              _searchController.clear();
              _controller.selectEvent(value);
            }
          },
  );

  Widget _summary() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _controller.event!.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            '${_controller.event!.startDate ?? '—'} → ${_controller.event!.endDate ?? '—'}',
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 30,
            runSpacing: 12,
            children: [
              _SummaryMetric(
                copy: _registered,
                value: '${_controller.event!.attendeesRegistered}',
              ),
              _SummaryMetric(
                copy: _checkedIn,
                value: '${_controller.stats.totalCheckedIn}',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _searchBar() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _controller.applySearch,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
                label: BilingualText(_search),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _controller.applySearch(_searchController.text),
            child: const BilingualText(_searchAction),
          ),
        ],
      ),
    ),
  );

  Widget _attendeeCard(TicketAttendee attendee) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              TicketAttendeePage(controller: _controller, attendee: attendee),
        ),
      ),
      leading: CircleAvatar(
        child: Text(
          attendee.fullName.isEmpty ? '?' : attendee.fullName.substring(0, 1),
        ),
      ),
      title: Text(attendee.fullName),
      subtitle: Text(
        '${attendee.shortId} · ${attendee.productTitle ?? attendee.productId}\n'
        '${attendee.email ?? '—'}',
      ),
      trailing: BilingualText(
        attendee.isCheckedIn ? _checked : _notChecked,
        textAlign: TextAlign.end,
      ),
    ),
  );

  Future<void> _scanTicket() async {
    final code = await _scanner.scan(
      context,
      title: '${_scan.primary(context)}\n${_scan.secondary(context)}',
      instruction:
          '${_scanInstruction.primary(context)}\n${_scanInstruction.secondary(context)}',
      unavailableMessage:
          '${_cameraUnavailable.primary(context)}\n${_cameraUnavailable.secondary(context)}',
      cancelLabel:
          '${_cancel.primary(context)} / ${_cancel.secondary(context)}',
    );
    if (code == null || !mounted) return;
    final result = await _controller.scanAndCheckIn(code);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          result.type == TicketScanResultType.checkedIn
              ? Icons.check_circle_rounded
              : Icons.error_outline_rounded,
          size: 52,
          color: result.type == TicketScanResultType.checkedIn
              ? Colors.green
              : Theme.of(context).colorScheme.error,
        ),
        title: result.attendee == null ? null : Text(result.attendee!.fullName),
        content: BilingualText(
          ticketScanResultCopy(result.type),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const BilingualText(
              BilingualCopy(zh: '继续核销', en: 'Continue scanning'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.copy, required this.value});
  final BilingualCopy copy;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BilingualText(copy),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    ],
  );
}
