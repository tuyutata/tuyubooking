import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/ticket/ticket_controller.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';

final class TicketAttendeePage extends StatefulWidget {
  const TicketAttendeePage({
    required this.controller,
    required this.attendee,
    super.key,
  });

  final TicketController controller;
  final TicketAttendee attendee;

  @override
  State<TicketAttendeePage> createState() => _TicketAttendeePageState();
}

final class _TicketAttendeePageState extends State<TicketAttendeePage> {
  static const _title = BilingualCopy(zh: '票券详情', en: 'Ticket details');
  static const _ticket = BilingualCopy(zh: '票券编号', en: 'Ticket ID');
  static const _status = BilingualCopy(zh: '票券状态', en: 'Ticket status');
  static const _product = BilingualCopy(zh: '票券类型', en: 'Ticket type');
  static const _order = BilingualCopy(zh: '订单编号', en: 'Order ID');
  static const _email = BilingualCopy(zh: '电子邮箱', en: 'Email');
  static const _notes = BilingualCopy(zh: '备注', en: 'Notes');
  static const _checkIn = BilingualCopy(zh: '签到', en: 'Check in');
  static const _checkOut = BilingualCopy(zh: '签出', en: 'Check out');

  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final attendee = widget.attendee;
    return Scaffold(
      appBar: AppBar(title: const BilingualText(_title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            attendee.fullName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _line(_ticket, attendee.shortId),
          _line(_status, _ticketStatus(attendee.status).primary(context)),
          _line(_product, attendee.productTitle ?? attendee.productId),
          _line(_order, attendee.orderId),
          if (attendee.email?.isNotEmpty == true)
            _line(_email, attendee.email!),
          if (attendee.notes?.isNotEmpty == true)
            _line(_notes, attendee.notes!),
          const SizedBox(height: 20),
          if (attendee.status == 'ACTIVE')
            FilledButton.icon(
              onPressed: _acting ? null : _changeStatus,
              icon: Icon(
                attendee.isCheckedIn
                    ? Icons.logout_rounded
                    : Icons.how_to_reg_rounded,
              ),
              label: BilingualText(attendee.isCheckedIn ? _checkOut : _checkIn),
            ),
        ],
      ),
    );
  }

  Widget _line(BilingualCopy label, String value) => Card(
    child: ListTile(
      title: BilingualText(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Text(value),
      ),
    ),
  );

  Future<void> _changeStatus() async {
    setState(() => _acting = true);
    final result = await widget.controller.changeCheckIn(
      widget.attendee,
      widget.attendee.isCheckedIn
          ? TicketCheckAction.checkOut
          : TicketCheckAction.checkIn,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: BilingualText(
          ticketScanResultCopy(result.type),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const BilingualText(BilingualCopy(zh: '确定', en: 'OK')),
          ),
        ],
      ),
    );
    if (mounted &&
        (result.type == TicketScanResultType.checkedIn ||
            result.type == TicketScanResultType.checkedOut)) {
      Navigator.of(context).pop();
    }
  }
}

BilingualCopy _ticketStatus(String value) => switch (value) {
  'ACTIVE' => const BilingualCopy(zh: '有效', en: 'Active'),
  'CANCELLED' => const BilingualCopy(zh: '已取消', en: 'Cancelled'),
  'AWAITING_PAYMENT' => const BilingualCopy(zh: '等待付款', en: 'Awaiting payment'),
  _ => BilingualCopy(zh: value, en: value),
};

BilingualCopy ticketScanResultCopy(TicketScanResultType type) => switch (type) {
  TicketScanResultType.checkedIn => const BilingualCopy(
    zh: '签到成功',
    en: 'Check-in successful',
  ),
  TicketScanResultType.checkedOut => const BilingualCopy(
    zh: '签出成功',
    en: 'Check-out successful',
  ),
  TicketScanResultType.duplicate => const BilingualCopy(
    zh: '该票券已经签到',
    en: 'This ticket is already checked in',
  ),
  TicketScanResultType.invalidCode => const BilingualCopy(
    zh: '不是有效的 Hi.Events 票券二维码',
    en: 'Not a valid Hi.Events ticket QR code',
  ),
  TicketScanResultType.notFound => const BilingualCopy(
    zh: '当前活动中找不到该票券',
    en: 'Ticket not found in this event',
  ),
  TicketScanResultType.cancelled => const BilingualCopy(
    zh: '该票券已经取消',
    en: 'This ticket is cancelled',
  ),
  TicketScanResultType.awaitingPayment => const BilingualCopy(
    zh: '该票券对应订单仍在等待付款',
    en: 'The ticket order is awaiting payment',
  ),
  TicketScanResultType.permissionDenied => const BilingualCopy(
    zh: '当前员工没有核销权限',
    en: 'This employee cannot check in tickets',
  ),
  TicketScanResultType.conflict => const BilingualCopy(
    zh: '票券状态冲突，请刷新后重试',
    en: 'Ticket status conflict; refresh and retry',
  ),
  TicketScanResultType.failed => const BilingualCopy(
    zh: '票券操作失败',
    en: 'Ticket operation failed',
  ),
};
