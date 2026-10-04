import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/hotel/hotel_controller.dart';
import 'package:tuyubooking/client/hotel/hotel_models.dart';
import 'package:tuyubooking/client/hotel/hotel_repository.dart';
import 'package:tuyubooking/client/hotel/hotel_reservation_page.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

final class HotelFrontDeskPage extends StatefulWidget {
  const HotelFrontDeskPage({
    required this.session,
    required this.onSignOut,
    super.key,
  });

  final EmployeeSession session;
  final Future<void> Function() onSignOut;

  @override
  State<HotelFrontDeskPage> createState() => _HotelFrontDeskPageState();
}

final class _HotelFrontDeskPageState extends State<HotelFrontDeskPage> {
  static const _title = BilingualCopy(zh: '酒店前台', en: 'Hotel front desk');
  static const _today = BilingualCopy(zh: '今日', en: 'Today');
  static const _availability = BilingualCopy(zh: '房态', en: 'Availability');
  static const _rooms = BilingualCopy(zh: '客房', en: 'Rooms');
  static const _arrivals = BilingualCopy(zh: '今日抵达', en: 'Arrivals');
  static const _departures = BilingualCopy(zh: '今日离店', en: 'Departures');
  static const _inHouse = BilingualCopy(zh: '在住客人', en: 'In house');
  static const _empty = BilingualCopy(zh: '当前没有记录', en: 'No records');
  static const _newBooking = BilingualCopy(zh: '新建预订', en: 'New reservation');
  static const _failed = BilingualCopy(
    zh: '酒店前台暂时不可用',
    en: 'Hotel front desk is unavailable',
  );
  static const _retry = BilingualCopy(zh: '重试', en: 'Retry');
  static const _signOut = BilingualCopy(zh: '退出登录', en: 'Sign out');
  static const _totalRooms = BilingualCopy(zh: '总房间', en: 'Total rooms');
  static const _availableRooms = BilingualCopy(zh: '可售', en: 'Available');
  static const _rate = BilingualCopy(zh: '房价', en: 'Rate');
  static const _floor = BilingualCopy(zh: '楼层', en: 'Floor');
  static const _updateFailed = BilingualCopy(
    zh: '房态更新失败',
    en: 'Room status update failed',
  );

  late final HotelController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HotelController(HotelRepository(widget.session));
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const BilingualText(_title),
          actions: [
            if (_controller.properties.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _controller.property?.name,
                    isExpanded: true,
                    items: _controller.properties
                        .map(
                          (property) => DropdownMenuItem(
                            value: property.name,
                            child: Text(
                              property.city.isEmpty
                                  ? property.displayName
                                  : '${property.displayName} · ${property.city}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _controller.isActing
                        ? null
                        : (value) {
                            if (value != null) {
                              _controller.selectProperty(value);
                            }
                          },
                  ),
                ),
              ),
            IconButton(
              onPressed: widget.onSignOut,
              tooltip: _signOut.primary(context),
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(child: BilingualText(_today, textAlign: TextAlign.center)),
              Tab(
                child: BilingualText(
                  _availability,
                  textAlign: TextAlign.center,
                ),
              ),
              Tab(child: BilingualText(_rooms, textAlign: TextAlign.center)),
            ],
          ),
        ),
        body: SafeArea(child: _body()),
        floatingActionButton: _controller.status == HotelStatus.ready
            ? FloatingActionButton.extended(
                onPressed: _showBooking,
                icon: const Icon(Icons.add_rounded),
                label: const BilingualText(_newBooking),
              )
            : null,
      ),
    ),
  );

  Widget _body() {
    if (_controller.status == HotelStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.status == HotelStatus.failed) {
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
    return TabBarView(children: [_todayTab(), _availabilityTab(), _roomsTab()]);
  }

  Widget _todayTab() {
    final snapshot = _controller.snapshot!;
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          _reservationSection(_arrivals, snapshot.arrivals),
          _reservationSection(_departures, snapshot.departures),
          _reservationSection(_inHouse, snapshot.inHouse),
        ],
      ),
    );
  }

  Widget _reservationSection(
    BilingualCopy title,
    List<HotelReservation> reservations,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            BilingualText(
              title,
              primaryStyle: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            Badge(label: Text('${reservations.length}')),
          ],
        ),
      ),
      if (reservations.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: BilingualText(_empty),
        )
      else
        ...reservations.map(_reservationCard),
      const SizedBox(height: 12),
    ],
  );

  Widget _reservationCard(HotelReservation reservation) => Card(
    child: ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HotelReservationPage(
            controller: _controller,
            reservation: reservation.name,
          ),
        ),
      ),
      leading: CircleAvatar(
        child: Text(
          reservation.room.isEmpty ? '?' : reservation.room.substring(0, 1),
        ),
      ),
      title: Text(reservation.guestName),
      subtitle: Text(
        '${reservation.checkInDate} → ${reservation.checkOutDate}\n'
        '${reservation.roomType}${reservation.room.isEmpty ? '' : ' · ${reservation.room}'}',
      ),
      trailing: BilingualText(
        _reservationStatus(reservation.status),
        textAlign: TextAlign.end,
      ),
    ),
  );

  Widget _availabilityTab() {
    final availability = _controller.availability!;
    if (availability.rows.isEmpty) {
      return const Center(child: BilingualText(_empty));
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: availability.rows.length,
        itemBuilder: (context, index) {
          final row = availability.rows[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const BilingualText(_totalRooms),
                      const SizedBox(width: 8),
                      Text('${row.totalRooms}'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: row.cells
                          .map(
                            (cell) => Container(
                              width: 118,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cell.available > 0
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cell.date),
                                  const SizedBox(height: 8),
                                  const BilingualText(_availableRooms),
                                  Text(
                                    '${cell.available}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const BilingualText(_rate),
                                  Text(cell.rate.toStringAsFixed(2)),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _roomsTab() {
    final rooms = _controller.snapshot!.rooms;
    if (rooms.isEmpty) return const Center(child: BilingualText(_empty));
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: rooms.length,
            itemBuilder: (context, index) => _roomCard(rooms[index]),
          ),
        );
      },
    );
  }

  Widget _roomCard(HotelRoom room) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.number,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                enabled: !_controller.isActing,
                onSelected: (value) => _setHousekeeping(room, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'Clean',
                    child: BilingualText(BilingualCopy(zh: '干净', en: 'Clean')),
                  ),
                  PopupMenuItem(
                    value: 'Dirty',
                    child: BilingualText(BilingualCopy(zh: '待清洁', en: 'Dirty')),
                  ),
                  PopupMenuItem(
                    value: 'Inspected',
                    child: BilingualText(
                      BilingualCopy(zh: '已检查', en: 'Inspected'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Out of Order',
                    child: BilingualText(
                      BilingualCopy(zh: '停用', en: 'Out of order'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(room.roomType),
          const Spacer(),
          if (room.floor.isNotEmpty)
            Row(
              children: [
                const BilingualText(_floor),
                const SizedBox(width: 8),
                Text(room.floor),
              ],
            ),
          const SizedBox(height: 8),
          BilingualText(_occupancyStatus(room.occupancyStatus)),
          const SizedBox(height: 8),
          BilingualText(_housekeepingStatus(room.housekeepingStatus)),
        ],
      ),
    ),
  );

  Future<void> _setHousekeeping(HotelRoom room, String value) async {
    final succeeded = await _controller.updateHousekeeping(room.name, value);
    if (!mounted || succeeded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: BilingualText(_updateFailed)));
  }

  Future<void> _showBooking() async {
    final options = _controller.bookingOptions;
    if (options == null || options.roomTypes.isEmpty) return;
    final guestName = TextEditingController();
    final phone = TextEditingController();
    var roomType = options.roomTypes.first.value;
    var mealPlan = options.mealPlans.isEmpty
        ? ''
        : options.mealPlans.first.value;
    var checkIn = DateTime.now();
    var checkOut = DateTime.now().add(const Duration(days: 1));
    var adults = 1;
    var children = 0;
    var selectedGuest = '';
    var matches = const <HotelGuest>[];
    var searching = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const BilingualText(_newBooking),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: guestName,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      label: const BilingualText(
                        BilingualCopy(zh: '住客姓名', en: 'Guest name'),
                      ),
                      suffixIcon: IconButton(
                        onPressed: searching
                            ? null
                            : () async {
                                setDialogState(() => searching = true);
                                final found = await _controller.searchGuests(
                                  guestName.text,
                                );
                                setDialogState(() {
                                  matches = found;
                                  searching = false;
                                });
                              },
                        icon: searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_search_outlined),
                      ),
                    ),
                  ),
                  if (matches.isNotEmpty)
                    ...matches
                        .take(5)
                        .map(
                          (guest) => ListTile(
                            title: Text(guest.fullName),
                            subtitle: Text(
                              guest.phone.isEmpty ? guest.email : guest.phone,
                            ),
                            trailing: guest.blacklisted
                                ? const Icon(Icons.block, color: Colors.red)
                                : null,
                            onTap: guest.blacklisted
                                ? null
                                : () => setDialogState(() {
                                    selectedGuest = guest.name;
                                    guestName.text = guest.fullName;
                                    phone.text = guest.phone;
                                    matches = const [];
                                  }),
                          ),
                        ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: BilingualText(
                        BilingualCopy(zh: '手机号', en: 'Phone'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: roomType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: BilingualText(
                        BilingualCopy(zh: '房型', en: 'Room type'),
                      ),
                    ),
                    items: options.roomTypes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.value,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setDialogState(() => roomType = value ?? roomType),
                  ),
                  if (options.mealPlans.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: mealPlan,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        label: BilingualText(
                          BilingualCopy(zh: '餐饮方案', en: 'Meal plan'),
                        ),
                      ),
                      items: options.mealPlans
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.value,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setDialogState(() => mealPlan = value ?? mealPlan),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate: checkIn,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (selected != null) {
                            setDialogState(() {
                              checkIn = selected;
                              if (!checkOut.isAfter(checkIn)) {
                                checkOut = checkIn.add(const Duration(days: 1));
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: BilingualText(
                          BilingualCopy(
                            zh: '入住 ${_date(checkIn)}',
                            en: 'Check-in ${_date(checkIn)}',
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate: checkOut,
                            firstDate: checkIn.add(const Duration(days: 1)),
                            lastDate: DateTime.now().add(
                              const Duration(days: 731),
                            ),
                          );
                          if (selected != null) {
                            setDialogState(() => checkOut = selected);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: BilingualText(
                          BilingualCopy(
                            zh: '退房 ${_date(checkOut)}',
                            en: 'Check-out ${_date(checkOut)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: adults,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            label: BilingualText(
                              BilingualCopy(zh: '成人', en: 'Adults'),
                            ),
                          ),
                          items: List.generate(8, (index) => index + 1)
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) =>
                              setDialogState(() => adults = value ?? adults),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: children,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            label: BilingualText(
                              BilingualCopy(zh: '儿童', en: 'Children'),
                            ),
                          ),
                          items: List.generate(7, (value) => value)
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) => setDialogState(
                            () => children = value ?? children,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const BilingualText(BilingualCopy(zh: '取消', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: _controller.isActing || guestName.text.trim().isEmpty
                  ? null
                  : () async {
                      final receipt = await _controller.createBooking(
                        HotelBookingRequest(
                          guestName: guestName.text.trim(),
                          phone: phone.text.trim(),
                          guest: selectedGuest,
                          roomType: roomType,
                          checkInDate: _date(checkIn),
                          checkOutDate: _date(checkOut),
                          adults: adults,
                          children: children,
                          mealPlan: mealPlan,
                        ),
                      );
                      if (dialogContext.mounted && receipt != null) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
              child: const BilingualText(
                BilingualCopy(zh: '创建预订', en: 'Create reservation'),
              ),
            ),
          ],
        ),
      ),
    );
    guestName.dispose();
    phone.dispose();
    if (submitted != true && mounted && _controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: BilingualText(
            BilingualCopy(zh: '预订创建失败', en: 'Reservation creation failed'),
          ),
        ),
      );
    }
  }
}

BilingualCopy _reservationStatus(String value) => switch (value) {
  'Confirmed' => const BilingualCopy(zh: '已确认', en: 'Confirmed'),
  'Checked In' => const BilingualCopy(zh: '已入住', en: 'Checked in'),
  'Checked Out' => const BilingualCopy(zh: '已退房', en: 'Checked out'),
  'Cancelled' => const BilingualCopy(zh: '已取消', en: 'Cancelled'),
  _ => BilingualCopy(zh: value, en: value),
};

BilingualCopy _occupancyStatus(String value) => switch (value) {
  'Vacant' => const BilingualCopy(zh: '空房', en: 'Vacant'),
  'Occupied' => const BilingualCopy(zh: '已入住', en: 'Occupied'),
  _ => BilingualCopy(zh: value, en: value),
};

BilingualCopy _housekeepingStatus(String value) => switch (value) {
  'Clean' => const BilingualCopy(zh: '干净', en: 'Clean'),
  'Dirty' => const BilingualCopy(zh: '待清洁', en: 'Dirty'),
  'Inspected' => const BilingualCopy(zh: '已检查', en: 'Inspected'),
  'Out of Order' => const BilingualCopy(zh: '停用', en: 'Out of order'),
  _ => BilingualCopy(zh: value, en: value),
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
