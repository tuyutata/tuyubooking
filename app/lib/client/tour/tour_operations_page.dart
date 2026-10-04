import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/tour/tour_booking_detail_page.dart';
import 'package:tuyubooking/client/tour/tour_controller.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';
import 'package:tuyubooking/client/tour/tour_repository.dart';

final class TourOperationsPage extends StatefulWidget {
  const TourOperationsPage({
    required this.session,
    required this.onSignOut,
    super.key,
  });

  final EmployeeSession session;
  final Future<void> Function() onSignOut;

  @override
  State<TourOperationsPage> createState() => _TourOperationsPageState();
}

final class _TourOperationsPageState extends State<TourOperationsPage> {
  static const _title = BilingualCopy(zh: '旅行团运营', en: 'Tour operations');
  static const _departures = BilingualCopy(
    zh: '近期团期',
    en: 'Upcoming departures',
  );
  static const _bookings = BilingualCopy(zh: '预订', en: 'Bookings');
  static const _allProducts = BilingualCopy(
    zh: '全部旅行产品',
    en: 'All travel products',
  );
  static const _product = BilingualCopy(zh: '旅行产品', en: 'Travel product');
  static const _emptyDepartures = BilingualCopy(
    zh: '当前没有近期团期',
    en: 'No upcoming departures',
  );
  static const _emptyBookings = BilingualCopy(
    zh: '没有符合条件的预订',
    en: 'No matching bookings',
  );
  static const _remaining = BilingualCopy(zh: '剩余人数', en: 'Remaining places');
  static const _unlimited = BilingualCopy(zh: '不限人数', en: 'Unlimited');
  static const _days = BilingualCopy(zh: '天数', en: 'Days');
  static const _nights = BilingualCopy(zh: '晚数', en: 'Nights');
  static const _search = BilingualCopy(
    zh: '预订编号或联系人',
    en: 'Booking number or contact',
  );
  static const _status = BilingualCopy(zh: '预订状态', en: 'Booking status');
  static const _allStatuses = BilingualCopy(zh: '全部状态', en: 'All statuses');
  static const _dates = BilingualCopy(zh: '出发日期', en: 'Departure dates');
  static const _apply = BilingualCopy(zh: '查询', en: 'Search');
  static const _clear = BilingualCopy(zh: '清除', en: 'Clear');
  static const _loadMore = BilingualCopy(zh: '加载更多', en: 'Load more');
  static const _failed = BilingualCopy(
    zh: '旅行团运营暂时不可用',
    en: 'Tour operations are unavailable',
  );
  static const _retry = BilingualCopy(zh: '重试', en: 'Retry');
  static const _signOut = BilingualCopy(zh: '退出登录', en: 'Sign out');
  static const _pax = BilingualCopy(zh: '人数', en: 'Travelers');
  static const _amount = BilingualCopy(zh: '金额', en: 'Amount');

  static const _bookingStatuses = [
    'draft',
    'on_hold',
    'awaiting_payment',
    'confirmed',
    'in_progress',
    'completed',
    'expired',
    'cancelled',
  ];

  late final TourController _controller;
  final _searchController = TextEditingController();
  String? _bookingStatus;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _controller = TourController(TourRepository(widget.session));
    _controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: AnimatedBuilder(
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
          bottom: const TabBar(
            tabs: [
              Tab(
                child: BilingualText(_departures, textAlign: TextAlign.center),
              ),
              Tab(child: BilingualText(_bookings, textAlign: TextAlign.center)),
            ],
          ),
        ),
        body: SafeArea(child: _body()),
      ),
    ),
  );

  Widget _body() {
    if (_controller.status == TourStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.status == TourStatus.failed) {
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
    return TabBarView(children: [_departuresTab(), _bookingsTab()]);
  }

  Widget _productFilter() => DropdownButtonFormField<String>(
    initialValue: _controller.selectedProductId ?? '',
    isExpanded: true,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.map_outlined),
      label: BilingualText(_product),
    ),
    items: [
      const DropdownMenuItem(value: '', child: BilingualText(_allProducts)),
      ..._controller.products.map(
        (product) => DropdownMenuItem(
          value: product.id,
          child: Text(product.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: _controller.isActing
        ? null
        : (value) => _controller.selectProduct(value),
  );

  Widget _departuresTab() {
    final departures = _controller.upcomingDepartures;
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
        children: [
          _productFilter(),
          const SizedBox(height: 18),
          if (departures.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: BilingualText(_emptyDepartures)),
            )
          else
            ...departures.map(_departureCard),
        ],
      ),
    );
  }

  Widget _departureCard(TourDeparture departure) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _controller.productName(departure.productId),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${departure.dateLocal} · ${_time(departure.startsAt)} · ${departure.timezone}',
                    ),
                  ],
                ),
              ),
              BilingualText(
                _departureStatus(departure.status),
                textAlign: TextAlign.end,
              ),
            ],
          ),
          const Divider(height: 26),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Metric(
                label: departure.unlimited ? _unlimited : _remaining,
                value: departure.unlimited
                    ? '∞'
                    : '${departure.remainingPax ?? 0}',
              ),
              if (departure.days != null)
                _Metric(label: _days, value: '${departure.days}'),
              if (departure.nights != null)
                _Metric(label: _nights, value: '${departure.nights}'),
            ],
          ),
          if (departure.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(departure.notes!),
          ],
        ],
      ),
    ),
  );

  Widget _bookingsTab() => RefreshIndicator(
    onRefresh: _controller.refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      children: [
        _bookingFilters(),
        const SizedBox(height: 18),
        if (_controller.bookings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: BilingualText(_emptyBookings)),
          )
        else
          ..._controller.bookings.map(_bookingCard),
        if (_controller.canLoadMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: _controller.status == TourStatus.loadingMore
                  ? null
                  : _controller.loadMoreBookings,
              child: _controller.status == TourStatus.loadingMore
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const BilingualText(_loadMore),
            ),
          ),
      ],
    ),
  );

  Widget _bookingFilters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final fields = [
            SizedBox(
              width: wide ? 280 : double.infinity,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _applyFilters(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search_rounded),
                  label: BilingualText(_search),
                ),
              ),
            ),
            SizedBox(
              width: wide ? 220 : double.infinity,
              child: DropdownButtonFormField<String>(
                initialValue: _bookingStatus ?? '',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  label: BilingualText(_status),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: BilingualText(_allStatuses),
                  ),
                  ..._bookingStatuses.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: BilingualText(_bookingStatusCopy(status)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _bookingStatus = value?.isEmpty == true ? null : value,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectDates,
              icon: const Icon(Icons.date_range_outlined),
              label: _dateRange == null
                  ? const BilingualText(_dates)
                  : Text(
                      '${_date(_dateRange!.start)} → ${_date(_dateRange!.end)}',
                    ),
            ),
            FilledButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.manage_search_rounded),
              label: const BilingualText(_apply),
            ),
            TextButton(
              onPressed: _clearFilters,
              child: const BilingualText(_clear),
            ),
          ];
          if (wide) {
            return Wrap(spacing: 12, runSpacing: 12, children: fields);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: fields
                .expand((field) => [field, const SizedBox(height: 12)])
                .toList(growable: false),
          );
        },
      ),
    ),
  );

  Widget _bookingCard(TourBookingSummary booking) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TourBookingDetailPage(
            controller: _controller,
            bookingId: booking.id,
          ),
        ),
      ),
      leading: const CircleAvatar(child: Icon(Icons.luggage_outlined)),
      title: Text(
        booking.bookingNumber,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${booking.startDate ?? '—'} → ${booking.endDate ?? '—'}\n'
        '${booking.contactEmail ?? '—'}',
      ),
      trailing: SizedBox(
        width: 125,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            BilingualText(
              _bookingStatusCopy(booking.status),
              textAlign: TextAlign.end,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              '${_pax.primary(context)} ${booking.pax ?? 0} · '
              '${_amount.primary(context)} ${_money(booking.sellCurrency, booking.sellAmountCents)}',
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _dateRange,
    );
    if (selected != null && mounted) setState(() => _dateRange = selected);
  }

  Future<void> _applyFilters() => _controller.applyBookingFilters(
    search: _searchController.text,
    bookingStatus: _bookingStatus,
    from: _dateRange == null ? null : _date(_dateRange!.start),
    to: _dateRange == null ? null : _date(_dateRange!.end),
  );

  Future<void> _clearFilters() async {
    _searchController.clear();
    setState(() {
      _bookingStatus = null;
      _dateRange = null;
    });
    await _applyFilters();
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final BilingualCopy label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BilingualText(label),
      const SizedBox(height: 3),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    ],
  );
}

BilingualCopy _departureStatus(String value) => switch (value) {
  'open' => const BilingualCopy(zh: '开放', en: 'Open'),
  'closed' => const BilingualCopy(zh: '关闭', en: 'Closed'),
  'sold_out' => const BilingualCopy(zh: '售罄', en: 'Sold out'),
  'cancelled' => const BilingualCopy(zh: '已取消', en: 'Cancelled'),
  _ => BilingualCopy(zh: value, en: value),
};

BilingualCopy _bookingStatusCopy(String value) => switch (value) {
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

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _time(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

String _money(String? currency, int? cents) {
  if (currency == null || cents == null) return '—';
  return '$currency ${(cents / 100).toStringAsFixed(2)}';
}
