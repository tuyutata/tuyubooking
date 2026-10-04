typedef HotelJson = Map<String, Object?>;

HotelJson hotelObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> hotelList(Object? value) => value is List ? value : const [];

String _text(Object? value) => value?.toString() ?? '';
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
double _decimal(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
bool _flag(Object? value) =>
    value == true || value == 1 || _text(value).toLowerCase() == 'true';

final class HotelProperty {
  const HotelProperty({
    required this.name,
    required this.displayName,
    required this.city,
  });

  factory HotelProperty.fromJson(HotelJson json) => HotelProperty(
    name: _text(json['name']),
    displayName: _text(json['property_name']).isEmpty
        ? _text(json['name'])
        : _text(json['property_name']),
    city: _text(json['city']),
  );

  final String name;
  final String displayName;
  final String city;
}

final class HotelReservation {
  const HotelReservation({
    required this.name,
    required this.guestName,
    required this.roomType,
    required this.room,
    required this.status,
    required this.checkInDate,
    required this.checkOutDate,
    required this.adults,
    required this.children,
    required this.paidTotal,
    required this.balanceDue,
  });

  factory HotelReservation.fromJson(HotelJson json) => HotelReservation(
    name: _text(json['name']),
    guestName: _text(json['guest_name']),
    roomType: _text(json['room_type']),
    room: _text(json['room']),
    status: _text(json['status']),
    checkInDate: _text(json['check_in_date']),
    checkOutDate: _text(json['check_out_date']),
    adults: _integer(json['adults'], 1),
    children: _integer(json['children']),
    paidTotal: _decimal(json['paid_total']),
    balanceDue: _decimal(json['balance_due']),
  );

  final String name;
  final String guestName;
  final String roomType;
  final String room;
  final String status;
  final String checkInDate;
  final String checkOutDate;
  final int adults;
  final int children;
  final double paidTotal;
  final double balanceDue;
}

final class HotelRoom {
  const HotelRoom({
    required this.name,
    required this.number,
    required this.roomType,
    required this.floor,
    required this.housekeepingStatus,
    required this.occupancyStatus,
  });

  factory HotelRoom.fromJson(HotelJson json) => HotelRoom(
    name: _text(json['name']),
    number: _text(json['room_number']).isEmpty
        ? _text(json['name'])
        : _text(json['room_number']),
    roomType: _text(json['room_type']),
    floor: _text(json['floor']),
    housekeepingStatus: _text(json['housekeeping_status']),
    occupancyStatus: _text(json['occupancy_status']),
  );

  final String name;
  final String number;
  final String roomType;
  final String floor;
  final String housekeepingStatus;
  final String occupancyStatus;
}

final class HotelSnapshot {
  const HotelSnapshot({
    required this.date,
    required this.arrivals,
    required this.departures,
    required this.inHouse,
    required this.rooms,
  });

  factory HotelSnapshot.fromJson(HotelJson json) => HotelSnapshot(
    date: _text(json['date']),
    arrivals: _reservations(json['arrivals']),
    departures: _reservations(json['departures']),
    inHouse: _reservations(json['in_house']),
    rooms: hotelList(
      json['rooms'],
    ).map(hotelObject).map(HotelRoom.fromJson).toList(growable: false),
  );

  static List<HotelReservation> _reservations(Object? value) => hotelList(
    value,
  ).map(hotelObject).map(HotelReservation.fromJson).toList(growable: false);

  final String date;
  final List<HotelReservation> arrivals;
  final List<HotelReservation> departures;
  final List<HotelReservation> inHouse;
  final List<HotelRoom> rooms;
}

final class HotelAvailabilityCell {
  const HotelAvailabilityCell({
    required this.date,
    required this.available,
    required this.rate,
  });

  factory HotelAvailabilityCell.fromJson(HotelJson json) =>
      HotelAvailabilityCell(
        date: _text(json['date']),
        available: _integer(json['available']),
        rate: _decimal(json['rate']),
      );

  final String date;
  final int available;
  final double rate;
}

final class HotelAvailabilityRow {
  const HotelAvailabilityRow({
    required this.roomType,
    required this.label,
    required this.totalRooms,
    required this.cells,
  });

  factory HotelAvailabilityRow.fromJson(HotelJson json) => HotelAvailabilityRow(
    roomType: _text(json['room_type']),
    label: _text(json['room_type_name']).isEmpty
        ? _text(json['room_type'])
        : _text(json['room_type_name']),
    totalRooms: _integer(json['total_rooms']),
    cells: hotelList(json['cells'])
        .map(hotelObject)
        .map(HotelAvailabilityCell.fromJson)
        .toList(growable: false),
  );

  final String roomType;
  final String label;
  final int totalRooms;
  final List<HotelAvailabilityCell> cells;
}

final class HotelAvailability {
  const HotelAvailability({
    required this.start,
    required this.days,
    required this.dates,
    required this.rows,
  });

  factory HotelAvailability.fromJson(HotelJson json) => HotelAvailability(
    start: _text(json['start']),
    days: _integer(json['days']),
    dates: hotelList(json['dates']).map(_text).toList(growable: false),
    rows: hotelList(json['room_types'])
        .map(hotelObject)
        .map(HotelAvailabilityRow.fromJson)
        .toList(growable: false),
  );

  final String start;
  final int days;
  final List<String> dates;
  final List<HotelAvailabilityRow> rows;
}

final class HotelOption {
  const HotelOption({required this.value, required this.label});

  factory HotelOption.fromJson(HotelJson json) {
    final value = _text(
      json['name'] ?? json['room_type'] ?? json['meal_plan'] ?? json['value'],
    );
    final label = _text(
      json['label'] ?? json['room_type_name'] ?? json['title'] ?? value,
    );
    return HotelOption(value: value, label: label.isEmpty ? value : label);
  }

  final String value;
  final String label;
}

final class HotelBookingOptions {
  const HotelBookingOptions({required this.roomTypes, required this.mealPlans});

  factory HotelBookingOptions.fromJson(HotelJson json) => HotelBookingOptions(
    roomTypes: hotelList(json['room_types'])
        .map(hotelObject)
        .map(HotelOption.fromJson)
        .where((item) => item.value.isNotEmpty)
        .toList(growable: false),
    mealPlans: hotelList(json['meal_plans'])
        .map(hotelObject)
        .map(HotelOption.fromJson)
        .where((item) => item.value.isNotEmpty)
        .toList(growable: false),
  );

  final List<HotelOption> roomTypes;
  final List<HotelOption> mealPlans;
}

final class HotelGuest {
  const HotelGuest({
    required this.name,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.vip,
    required this.blacklisted,
    required this.stays,
  });

  factory HotelGuest.fromJson(HotelJson json) => HotelGuest(
    name: _text(json['name']),
    fullName: _text(json['full_name']),
    phone: _text(json['phone']),
    email: _text(json['email']),
    vip: _flag(json['vip']),
    blacklisted: _flag(json['blacklisted']),
    stays: _integer(json['stays']),
  );

  final String name;
  final String fullName;
  final String phone;
  final String email;
  final bool vip;
  final bool blacklisted;
  final int stays;
}

final class HotelReservationDetail {
  const HotelReservationDetail({
    required this.reservation,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.warnings,
  });

  factory HotelReservationDetail.fromJson(HotelJson json) {
    final actions = hotelObject(json['actions']);
    final reservation = hotelObject(json['reservation']).isEmpty
        ? json
        : hotelObject(json['reservation']);
    return HotelReservationDetail(
      reservation: HotelReservation.fromJson(reservation),
      canCheckIn: _flag(actions['can_check_in']),
      canCheckOut: _flag(actions['can_check_out']),
      warnings: hotelList(
        json['warnings'],
      ).map(_text).where((item) => item.isNotEmpty).toList(growable: false),
    );
  }

  final HotelReservation reservation;
  final bool canCheckIn;
  final bool canCheckOut;
  final List<String> warnings;
}

final class HotelBookingRequest {
  const HotelBookingRequest({
    required this.guestName,
    required this.roomType,
    required this.checkInDate,
    required this.checkOutDate,
    required this.adults,
    required this.children,
    this.phone = '',
    this.guest = '',
    this.mealPlan = '',
  });

  final String guestName;
  final String phone;
  final String guest;
  final String roomType;
  final String checkInDate;
  final String checkOutDate;
  final int adults;
  final int children;
  final String mealPlan;

  HotelJson toJson() => {
    'guest_name': guestName,
    if (phone.isNotEmpty) 'phone': phone,
    if (guest.isNotEmpty) 'guest': guest,
    'room_type': roomType,
    'check_in_date': checkInDate,
    'check_out_date': checkOutDate,
    'adults': adults,
    'children': children,
    if (mealPlan.isNotEmpty) 'meal_plan': mealPlan,
  };
}

final class HotelBookingReceipt {
  const HotelBookingReceipt({required this.reservation, required this.room});

  factory HotelBookingReceipt.fromJson(HotelJson json) {
    final rawReservation = json['reservation'];
    final reservation = rawReservation is Map
        ? _text(hotelObject(rawReservation)['name'])
        : _text(rawReservation);
    return HotelBookingReceipt(
      reservation: reservation,
      room: _text(json['room']),
    );
  }

  final String reservation;
  final String room;
}
