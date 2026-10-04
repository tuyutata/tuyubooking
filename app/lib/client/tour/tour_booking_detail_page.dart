import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/tour/tour_controller.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';

final class TourBookingDetailPage extends StatefulWidget {
  const TourBookingDetailPage({
    required this.controller,
    required this.bookingId,
    super.key,
  });

  final TourController controller;
  final String bookingId;

  @override
  State<TourBookingDetailPage> createState() => _TourBookingDetailPageState();
}

enum _BookingAction { confirm, cancel }

final class _ActionRequest {
  const _ActionRequest(this.action, this.note);
  final _BookingAction action;
  final String? note;
}

final class _TourBookingDetailPageState extends State<TourBookingDetailPage> {
  static const _title = BilingualCopy(zh: '旅行预订详情', en: 'Tour booking details');
  static const _failed = BilingualCopy(
    zh: '无法读取预订详情',
    en: 'Unable to load booking',
  );
  static const _retry = BilingualCopy(zh: '重试', en: 'Retry');
  static const _summary = BilingualCopy(zh: '预订摘要', en: 'Booking summary');
  static const _contact = BilingualCopy(zh: '联系人', en: 'Contact');
  static const _travelers = BilingualCopy(zh: '旅客', en: 'Travelers');
  static const _items = BilingualCopy(zh: '预订项目', en: 'Booking items');
  static const _status = BilingualCopy(zh: '状态', en: 'Status');
  static const _dates = BilingualCopy(zh: '旅行日期', en: 'Travel dates');
  static const _pax = BilingualCopy(zh: '人数', en: 'Travelers');
  static const _amount = BilingualCopy(zh: '预订金额', en: 'Booking amount');
  static const _confirm = BilingualCopy(zh: '确认预订', en: 'Confirm booking');
  static const _cancelBooking = BilingualCopy(zh: '取消预订', en: 'Cancel booking');
  static const _cancel = BilingualCopy(zh: '返回', en: 'Back');
  static const _note = BilingualCopy(
    zh: '操作备注（选填）',
    en: 'Action note (optional)',
  );
  static const _continue = BilingualCopy(zh: '继续', en: 'Continue');
  static const _pending = BilingualCopy(
    zh: '操作已提交，等待审批',
    en: 'Action submitted for approval',
  );
  static const _completed = BilingualCopy(zh: '操作已完成', en: 'Action completed');
  static const _actionFailed = BilingualCopy(
    zh: '操作未完成',
    en: 'Action was not completed',
  );
  static const _primary = BilingualCopy(zh: '主要联系人', en: 'Primary contact');
  static const _specialRequests = BilingualCopy(
    zh: '特殊需求',
    en: 'Special requests',
  );
  static const _empty = BilingualCopy(zh: '没有记录', en: 'No records');

  late Future<TourBookingBundle> _bundle;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _bundle = widget.controller.loadBookingBundle(widget.bookingId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BilingualText(_title)),
    body: FutureBuilder<TourBookingBundle>(
      future: _bundle,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BilingualText(_failed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => setState(_reload),
                  child: const BilingualText(_retry),
                ),
              ],
            ),
          );
        }
        return _content(snapshot.requireData);
      },
    ),
  );

  Widget _content(TourBookingBundle bundle) {
    final booking = bundle.booking;
    final summary = booking.summary;
    final canConfirm = summary.status == 'on_hold';
    final canCancel = !const {
      'cancelled',
      'completed',
      'expired',
    }.contains(summary.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Text(
          summary.bookingNumber,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        _section(_summary, [
          _line(_status, BilingualText(_bookingStatus(summary.status))),
          _line(
            _dates,
            Text('${summary.startDate ?? '—'} → ${summary.endDate ?? '—'}'),
          ),
          _line(_pax, Text('${summary.pax ?? 0}')),
          _line(
            _amount,
            Text(_money(summary.sellCurrency, summary.sellAmountCents)),
          ),
        ]),
        _section(_contact, [
          Text(booking.contactName.isEmpty ? '—' : booking.contactName),
          if (summary.contactEmail?.isNotEmpty == true)
            Text(summary.contactEmail!),
          if (booking.contactPhone?.isNotEmpty == true)
            Text(booking.contactPhone!),
        ]),
        _section(
          _items,
          bundle.items.isEmpty
              ? [const BilingualText(_empty)]
              : bundle.items
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.route_outlined),
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.startsAt ?? '—'} → ${item.endsAt ?? '—'}\n'
                          '${item.itemType} · ${item.status}',
                        ),
                        trailing: Text('×${item.quantity}'),
                      ),
                    )
                    .toList(growable: false),
        ),
        _section(
          _travelers,
          bundle.travelers.isEmpty
              ? [const BilingualText(_empty)]
              : bundle.travelers
                    .map(
                      (traveler) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            traveler.fullName.isEmpty
                                ? '?'
                                : traveler.fullName.substring(0, 1),
                          ),
                        ),
                        title: Text(traveler.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (traveler.email?.isNotEmpty == true)
                              Text(traveler.email!),
                            if (traveler.phone?.isNotEmpty == true)
                              Text(traveler.phone!),
                            if (traveler.specialRequests?.isNotEmpty ==
                                true) ...[
                              const BilingualText(_specialRequests),
                              Text(traveler.specialRequests!),
                            ],
                          ],
                        ),
                        trailing: traveler.isPrimary
                            ? const BilingualText(
                                _primary,
                                textAlign: TextAlign.end,
                              )
                            : null,
                      ),
                    )
                    .toList(growable: false),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (canConfirm)
              FilledButton.icon(
                onPressed: _acting
                    ? null
                    : () => _requestAction(_BookingAction.confirm),
                icon: const Icon(Icons.check_circle_outline),
                label: const BilingualText(_confirm),
              ),
            if (canCancel)
              OutlinedButton.icon(
                onPressed: _acting
                    ? null
                    : () => _requestAction(_BookingAction.cancel),
                icon: const Icon(Icons.cancel_outlined),
                label: const BilingualText(_cancelBooking),
              ),
          ],
        ),
      ],
    );
  }

  Widget _section(BilingualCopy title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            title,
            primaryStyle: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );

  Widget _line(BilingualCopy label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 145, child: BilingualText(label)),
        const SizedBox(width: 12),
        Expanded(child: value),
      ],
    ),
  );

  Future<void> _requestAction(_BookingAction action) async {
    final note = TextEditingController();
    final request = await showDialog<_ActionRequest>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: BilingualText(
          action == _BookingAction.confirm ? _confirm : _cancelBooking,
        ),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: BilingualText(_note),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const BilingualText(_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _ActionRequest(
                action,
                note.text.trim().isEmpty ? null : note.text.trim(),
              ),
            ),
            child: const BilingualText(_continue),
          ),
        ],
      ),
    );
    note.dispose();
    if (request == null || !mounted) return;
    setState(() => _acting = true);
    final outcome = request.action == _BookingAction.confirm
        ? await widget.controller.confirmBooking(
            widget.bookingId,
            note: request.note,
          )
        : await widget.controller.cancelBooking(
            widget.bookingId,
            note: request.note,
          );
    if (!mounted) return;
    final message = outcome == TourActionOutcome.pendingApproval
        ? _pending
        : outcome == TourActionOutcome.completed
        ? _completed
        : _actionFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: BilingualText(message)));
    setState(() {
      _acting = false;
      if (outcome != null) _reload();
    });
  }
}

BilingualCopy _bookingStatus(String value) => switch (value) {
  'draft' => const BilingualCopy(zh: '草稿', en: 'Draft'),
  'on_hold' => const BilingualCopy(zh: '保留中', en: 'On hold'),
  'awaiting_payment' => const BilingualCopy(zh: '等待付款', en: 'Awaiting payment'),
  'confirmed' => const BilingualCopy(zh: '已确认', en: 'Confirmed'),
  'in_progress' => const BilingualCopy(zh: '进行中', en: 'In progress'),
  'completed' => const BilingualCopy(zh: '已完成', en: 'Completed'),
  'expired' => const BilingualCopy(zh: '已过期', en: 'Expired'),
  'cancelled' => const BilingualCopy(zh: '已取消', en: 'Cancelled'),
  _ => BilingualCopy(zh: value, en: value),
};

String _money(String? currency, int? cents) {
  if (currency == null || cents == null) return '—';
  return '$currency ${(cents / 100).toStringAsFixed(2)}';
}
