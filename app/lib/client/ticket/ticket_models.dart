typedef TicketJson = Map<String, Object?>;

TicketJson ticketObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> ticketList(Object? value) => value is List ? value : const [];

String _text(Object? value) => value?.toString() ?? '';
String? _nullableText(Object? value) {
  final result = _text(value);
  return result.isEmpty ? null : result;
}

int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;

final class TicketPage<T> {
  const TicketPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  final List<T> items;
  final int total;
  final int page;
  final int perPage;
}

final class TicketEvent {
  const TicketEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.timezone,
    required this.attendeesRegistered,
  });

  factory TicketEvent.fromJson(TicketJson json) {
    final statistics = ticketObject(json['statistics']);
    return TicketEvent(
      id: _text(json['id']),
      title: _text(json['title']).isEmpty
          ? _text(json['id'])
          : _text(json['title']),
      startDate: _nullableText(json['start_date']),
      endDate: _nullableText(json['end_date']),
      status: _text(json['status']),
      timezone: _text(json['timezone']),
      attendeesRegistered: _integer(statistics['attendees_registered']),
    );
  }

  final String id;
  final String title;
  final String? startDate;
  final String? endDate;
  final String status;
  final String timezone;
  final int attendeesRegistered;
}

final class TicketCheckInStats {
  const TicketCheckInStats({required this.totalCheckedIn});

  factory TicketCheckInStats.fromJson(TicketJson json) => TicketCheckInStats(
    totalCheckedIn: _integer(json['total_checked_in_attendees']),
  );

  final int totalCheckedIn;
}

final class TicketCheckIn {
  const TicketCheckIn({
    required this.id,
    required this.shortId,
    required this.createdAt,
  });

  factory TicketCheckIn.fromJson(TicketJson json) => TicketCheckIn(
    id: _text(json['id']),
    shortId: _text(json['short_id']),
    createdAt: _text(json['created_at']),
  );

  final String id;
  final String shortId;
  final String createdAt;
}

final class TicketAttendee {
  const TicketAttendee({
    required this.id,
    required this.eventId,
    required this.orderId,
    required this.productId,
    required this.publicId,
    required this.shortId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.status,
    required this.notes,
    required this.productTitle,
    required this.checkIns,
    required this.checkedInAt,
  });

  factory TicketAttendee.fromJson(TicketJson json) {
    final product = ticketObject(json['product']);
    return TicketAttendee(
      id: _text(json['id']),
      eventId: _text(json['event_id']),
      orderId: _text(json['order_id']),
      productId: _text(json['product_id']),
      publicId: _text(json['public_id']),
      shortId: _text(json['short_id']),
      firstName: _text(json['first_name']),
      lastName: _text(json['last_name']),
      email: _nullableText(json['email']),
      status: _text(json['status']),
      notes: _nullableText(json['notes']),
      productTitle: _nullableText(product['title'] ?? product['name']),
      checkIns: ticketList(
        json['check_ins'],
      ).map(ticketObject).map(TicketCheckIn.fromJson).toList(growable: false),
      checkedInAt: _nullableText(json['checked_in_at']),
    );
  }

  final String id;
  final String eventId;
  final String orderId;
  final String productId;
  final String publicId;
  final String shortId;
  final String firstName;
  final String lastName;
  final String? email;
  final String status;
  final String? notes;
  final String? productTitle;
  final List<TicketCheckIn> checkIns;
  final String? checkedInAt;

  String get fullName => '$firstName $lastName'.trim();
  bool get isCheckedIn => checkedInAt != null || checkIns.isNotEmpty;
}

enum TicketCheckAction { checkIn, checkOut }

enum TicketScanResultType {
  checkedIn,
  checkedOut,
  duplicate,
  invalidCode,
  notFound,
  cancelled,
  awaitingPayment,
  permissionDenied,
  conflict,
  failed,
}

final class TicketScanResult {
  const TicketScanResult(this.type, {this.attendee});

  final TicketScanResultType type;
  final TicketAttendee? attendee;
}

/// Extracts the attendee token encoded by native Hi.Events tickets.
String? parseHiEventsTicketCode(String raw) {
  final value = raw.trim();
  if (RegExp(r'^A-[A-Za-z0-9_-]+$').hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  final productIndex = segments.indexOf('product');
  if (productIndex >= 0 && segments.length >= productIndex + 3) {
    final token = segments[productIndex + 2];
    return RegExp(r'^A-[A-Za-z0-9_-]+$').hasMatch(token) ? token : null;
  }
  return null;
}
