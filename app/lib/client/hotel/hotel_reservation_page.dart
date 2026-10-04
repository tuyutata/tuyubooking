import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/hotel/hotel_controller.dart';
import 'package:tuyubooking/client/hotel/hotel_models.dart';

final class HotelReservationPage extends StatefulWidget {
  const HotelReservationPage({
    required this.controller,
    required this.reservation,
    super.key,
  });

  final HotelController controller;
  final String reservation;

  @override
  State<HotelReservationPage> createState() => _HotelReservationPageState();
}

final class _HotelReservationPageState extends State<HotelReservationPage> {
  static const _title = BilingualCopy(zh: '预订详情', en: 'Reservation details');
  static const _failed = BilingualCopy(
    zh: '无法读取预订详情',
    en: 'Unable to load reservation',
  );
  static const _retry = BilingualCopy(zh: '重试', en: 'Retry');
  static const _guest = BilingualCopy(zh: '住客', en: 'Guest');
  static const _stay = BilingualCopy(zh: '住宿', en: 'Stay');
  static const _status = BilingualCopy(zh: '状态', en: 'Status');
  static const _balance = BilingualCopy(zh: '待付金额', en: 'Balance due');
  static const _checkIn = BilingualCopy(zh: '办理入住', en: 'Check in');
  static const _checkOut = BilingualCopy(zh: '办理退房', en: 'Check out');
  static const _actionFailed = BilingualCopy(
    zh: '操作未完成',
    en: 'Action was not completed',
  );

  late Future<HotelReservationDetail> _detail;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = widget.controller.loadReservationDetail(widget.reservation);
  }

  Future<void> _run(bool checkIn) async {
    setState(() => _acting = true);
    final succeeded = checkIn
        ? await widget.controller.checkIn(widget.reservation)
        : await widget.controller.checkOut(widget.reservation);
    if (!mounted) return;
    if (succeeded) {
      setState(_reload);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: BilingualText(_actionFailed)));
    }
    setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BilingualText(_title)),
    body: FutureBuilder<HotelReservationDetail>(
      future: _detail,
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

  Widget _content(HotelReservationDetail detail) {
    final reservation = detail.reservation;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          reservation.name,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        _DetailCard(
          label: _guest,
          value: reservation.guestName,
          icon: Icons.person_outline,
        ),
        _DetailCard(
          label: _stay,
          value:
              '${reservation.checkInDate}  →  ${reservation.checkOutDate}\n'
              '${reservation.roomType}${reservation.room.isEmpty ? '' : ' · ${reservation.room}'}',
          icon: Icons.bed_outlined,
        ),
        _DetailCard(
          label: _status,
          valueWidget: BilingualText(_reservationStatus(reservation.status)),
          icon: Icons.fact_check_outlined,
        ),
        _DetailCard(
          label: _balance,
          value: reservation.balanceDue.toStringAsFixed(2),
          icon: Icons.payments_outlined,
        ),
        if (detail.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...detail.warnings.map(
            (warning) => Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(warning),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (detail.canCheckIn)
              FilledButton.icon(
                onPressed: _acting ? null : () => _run(true),
                icon: const Icon(Icons.login_rounded),
                label: const BilingualText(_checkIn),
              ),
            if (detail.canCheckOut)
              FilledButton.icon(
                onPressed: _acting ? null : () => _run(false),
                icon: const Icon(Icons.logout_rounded),
                label: const BilingualText(_checkOut),
              ),
          ],
        ),
      ],
    );
  }
}

final class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.label,
    required this.icon,
    this.value = '',
    this.valueWidget,
  });

  final BilingualCopy label;
  final IconData icon;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: BilingualText(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: valueWidget ?? Text(value),
      ),
    ),
  );
}

BilingualCopy _reservationStatus(String value) => switch (value) {
  'Confirmed' => const BilingualCopy(zh: '已确认', en: 'Confirmed'),
  'Checked In' => const BilingualCopy(zh: '已入住', en: 'Checked in'),
  'Checked Out' => const BilingualCopy(zh: '已退房', en: 'Checked out'),
  'Cancelled' => const BilingualCopy(zh: '已取消', en: 'Cancelled'),
  _ => BilingualCopy(zh: value, en: value),
};
