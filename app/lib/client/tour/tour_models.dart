typedef TourJson = Map<String, Object?>;

TourJson tourObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> tourList(Object? value) => value is List ? value : const [];

String _text(Object? value) => value?.toString() ?? '';
String? _nullableText(Object? value) {
  final result = _text(value);
  return result.isEmpty ? null : result;
}

int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
bool _flag(Object? value) =>
    value == true || value == 1 || _text(value).toLowerCase() == 'true';

final class TourPage<T> {
  const TourPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;
}

final class TourProduct {
  const TourProduct({
    required this.id,
    required this.name,
    required this.status,
    required this.reference,
    required this.productTypeId,
  });

  factory TourProduct.fromJson(TourJson json) => TourProduct(
    id: _text(json['id']),
    name: _text(json['name']).isEmpty ? _text(json['id']) : _text(json['name']),
    status: _text(json['status']),
    reference: _text(json['reference']),
    productTypeId: _text(json['productTypeId']),
  );

  final String id;
  final String name;
  final String status;
  final String reference;
  final String productTypeId;
}

final class TourDeparture {
  const TourDeparture({
    required this.id,
    required this.productId,
    required this.itineraryId,
    required this.dateLocal,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.status,
    required this.unlimited,
    required this.initialPax,
    required this.remainingPax,
    required this.nights,
    required this.days,
    required this.notes,
  });

  factory TourDeparture.fromJson(TourJson json) => TourDeparture(
    id: _text(json['id']),
    productId: _text(json['productId']),
    itineraryId: _nullableText(json['itineraryId']),
    dateLocal: _text(json['dateLocal']),
    startsAt: _text(json['startsAt']),
    endsAt: _nullableText(json['endsAt']),
    timezone: _text(json['timezone']),
    status: _text(json['status']),
    unlimited: _flag(json['unlimited']),
    initialPax: json['initialPax'] == null
        ? null
        : _integer(json['initialPax']),
    remainingPax: json['remainingPax'] == null
        ? null
        : _integer(json['remainingPax']),
    nights: json['nights'] == null ? null : _integer(json['nights']),
    days: json['days'] == null ? null : _integer(json['days']),
    notes: _nullableText(json['notes']),
  );

  final String id;
  final String productId;
  final String? itineraryId;
  final String dateLocal;
  final String startsAt;
  final String? endsAt;
  final String timezone;
  final String status;
  final bool unlimited;
  final int? initialPax;
  final int? remainingPax;
  final int? nights;
  final int? days;
  final String? notes;
}

final class TourBookingSummary {
  const TourBookingSummary({
    required this.id,
    required this.bookingNumber,
    required this.status,
    required this.contactEmail,
    required this.sellCurrency,
    required this.sellAmountCents,
    required this.startDate,
    required this.endDate,
    required this.pax,
  });

  factory TourBookingSummary.fromJson(TourJson json) => TourBookingSummary(
    id: _text(json['id']),
    bookingNumber: _text(json['bookingNumber']),
    status: _text(json['status']),
    contactEmail: _nullableText(json['contactEmail']),
    sellCurrency: _nullableText(json['sellCurrency']),
    sellAmountCents: json['sellAmountCents'] == null
        ? null
        : _integer(json['sellAmountCents']),
    startDate: _nullableText(json['startDate']),
    endDate: _nullableText(json['endDate']),
    pax: json['pax'] == null ? null : _integer(json['pax']),
  );

  final String id;
  final String bookingNumber;
  final String status;
  final String? contactEmail;
  final String? sellCurrency;
  final int? sellAmountCents;
  final String? startDate;
  final String? endDate;
  final int? pax;
}

final class TourBookingDetail {
  const TourBookingDetail({
    required this.summary,
    required this.contactFirstName,
    required this.contactLastName,
    required this.contactPhone,
    required this.internalNotes,
  });

  factory TourBookingDetail.fromJson(TourJson json) => TourBookingDetail(
    summary: TourBookingSummary.fromJson(json),
    contactFirstName: _nullableText(json['contactFirstName']),
    contactLastName: _nullableText(json['contactLastName']),
    contactPhone: _nullableText(json['contactPhone']),
    internalNotes: _nullableText(json['internalNotes']),
  );

  final TourBookingSummary summary;
  final String? contactFirstName;
  final String? contactLastName;
  final String? contactPhone;
  final String? internalNotes;

  String get contactName => [
    contactFirstName,
    contactLastName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
}

final class TourBookingItem {
  const TourBookingItem({
    required this.id,
    required this.title,
    required this.status,
    required this.itemType,
    required this.productId,
    required this.availabilitySlotId,
    required this.startsAt,
    required this.endsAt,
    required this.quantity,
  });

  factory TourBookingItem.fromJson(TourJson json) => TourBookingItem(
    id: _text(json['id']),
    title: _text(json['title']),
    status: _text(json['status']),
    itemType: _text(json['itemType']),
    productId: _nullableText(json['productId']),
    availabilitySlotId: _nullableText(json['availabilitySlotId']),
    startsAt: _nullableText(json['startsAt']),
    endsAt: _nullableText(json['endsAt']),
    quantity: _integer(json['quantity'], 1),
  );

  final String id;
  final String title;
  final String status;
  final String itemType;
  final String? productId;
  final String? availabilitySlotId;
  final String? startsAt;
  final String? endsAt;
  final int quantity;
}

final class TourTraveler {
  const TourTraveler({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.participantType,
    required this.travelerCategory,
    required this.specialRequests,
    required this.isPrimary,
  });

  factory TourTraveler.fromJson(TourJson json) => TourTraveler(
    id: _text(json['id']),
    firstName: _text(json['firstName']),
    lastName: _text(json['lastName']),
    email: _nullableText(json['email']),
    phone: _nullableText(json['phone']),
    participantType: _text(json['participantType']),
    travelerCategory: _nullableText(json['travelerCategory']),
    specialRequests: _nullableText(json['specialRequests']),
    isPrimary: _flag(json['isPrimary']),
  );

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String participantType;
  final String? travelerCategory;
  final String? specialRequests;
  final bool isPrimary;

  String get fullName => '$firstName $lastName'.trim();
}

final class TourBookingBundle {
  const TourBookingBundle({
    required this.booking,
    required this.items,
    required this.travelers,
  });

  final TourBookingDetail booking;
  final List<TourBookingItem> items;
  final List<TourTraveler> travelers;
}

enum TourActionOutcome { completed, pendingApproval }
