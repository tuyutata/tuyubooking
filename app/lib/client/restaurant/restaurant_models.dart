enum RestaurantOrderType {
  dineIn('Dine In'),
  takeAway('Take Away');

  const RestaurantOrderType(this.upstreamValue);
  final String upstreamValue;
}

final class RestaurantPosProfile {
  const RestaurantPosProfile({
    required this.name,
    required this.branch,
    required this.company,
    required this.defaultCustomer,
    required this.currency,
    required this.cashier,
    required this.waiter,
    required this.owner,
    required this.paymentModes,
  });

  factory RestaurantPosProfile.fromUpstream(
    Map<String, Object?> limited,
    Map<String, Object?> full,
  ) => RestaurantPosProfile(
    name: _string(limited['pos_profile'] ?? full['name']),
    branch: _string(limited['branch'] ?? full['branch']),
    company: _string(limited['company'] ?? full['company']),
    defaultCustomer: _string(full['customer']),
    currency: _string(full['currency'], fallback: 'CNY'),
    cashier: _string(limited['cashier']),
    waiter: _string(limited['waiter']),
    owner: _string(limited['owner']),
    paymentModes: _list(full['payments'])
        .map(_map)
        .map((row) => _string(row['mode_of_payment']))
        .where((mode) => mode.isNotEmpty)
        .toList(growable: false),
  );

  final String name;
  final String branch;
  final String company;
  final String defaultCustomer;
  final String currency;
  final String cashier;
  final String waiter;
  final String owner;
  final List<String> paymentModes;
}

final class RestaurantMenuCategory {
  const RestaurantMenuCategory({required this.name, required this.label});

  factory RestaurantMenuCategory.fromJson(Map<String, Object?> json) =>
      RestaurantMenuCategory(
        name: _string(json['name']),
        label: _string(json['label'] ?? json['name']),
      );

  final String name;
  final String label;
}

final class RestaurantMenuItem {
  const RestaurantMenuItem({
    required this.code,
    required this.name,
    required this.price,
    required this.course,
    required this.courseLabel,
    required this.description,
    required this.specialDish,
  });

  factory RestaurantMenuItem.fromJson(Map<String, Object?> json) =>
      RestaurantMenuItem(
        code: _string(json['item']),
        name: _string(json['item_name'] ?? json['item']),
        price: _number(json['rate']),
        course: _string(json['course']),
        courseLabel: _string(json['course_label'] ?? json['course']),
        description: _string(json['description']),
        specialDish: _integer(json['special_dish']) == 1,
      );

  final String code;
  final String name;
  final double price;
  final String course;
  final String courseLabel;
  final String description;
  final bool specialDish;
}

final class RestaurantItemOptions {
  const RestaurantItemOptions({required this.variants, required this.addOns});

  final List<RestaurantMenuItem> variants;
  final List<RestaurantMenuItem> addOns;
}

final class RestaurantRoom {
  const RestaurantRoom({required this.name, required this.branch});

  factory RestaurantRoom.fromJson(Map<String, Object?> json) => RestaurantRoom(
    name: _string(json['name']),
    branch: _string(json['branch']),
  );

  final String name;
  final String branch;
}

final class RestaurantTable {
  const RestaurantTable({
    required this.name,
    required this.room,
    required this.occupied,
    required this.seats,
  });

  factory RestaurantTable.fromJson(Map<String, Object?> json) =>
      RestaurantTable(
        name: _string(json['name']),
        room: _string(json['restaurant_room']),
        occupied: _integer(json['occupied']) == 1,
        seats: _integer(json['no_of_seats']),
      );

  final String name;
  final String room;
  final bool occupied;
  final int seats;
}

final class RestaurantCartLine {
  const RestaurantCartLine({
    required this.item,
    required this.quantity,
    this.comment = '',
    this.isAddOn = false,
  });

  final RestaurantMenuItem item;
  final double quantity;
  final String comment;
  final bool isAddOn;

  double get amount => item.price * quantity;

  RestaurantCartLine copyWith({double? quantity, String? comment}) =>
      RestaurantCartLine(
        item: item,
        quantity: quantity ?? this.quantity,
        comment: comment ?? this.comment,
        isAddOn: isAddOn,
      );
}

final class RestaurantOrderReceipt {
  const RestaurantOrderReceipt({
    required this.name,
    required this.status,
    required this.total,
    required this.roundedTotal,
    required this.customer,
    required this.table,
    required this.modified,
  });

  factory RestaurantOrderReceipt.fromJson(Map<String, Object?> json) =>
      RestaurantOrderReceipt(
        name: _string(json['name']),
        status: _string(json['status'], fallback: 'Draft'),
        total: _number(json['grand_total'] ?? json['total']),
        roundedTotal: _number(
          json['rounded_total'] ?? json['grand_total'] ?? json['total'],
        ),
        customer: _string(json['customer']),
        table: _string(json['restaurant_table']),
        modified: _string(json['modified']),
      );

  final String name;
  final String status;
  final double total;
  final double roundedTotal;
  final String customer;
  final String table;
  final String modified;
}

final class RestaurantOrderRecord {
  const RestaurantOrderRecord({required this.receipt, required this.lines});

  factory RestaurantOrderRecord.fromJson(Map<String, Object?> json) =>
      RestaurantOrderRecord(
        receipt: RestaurantOrderReceipt.fromJson(json),
        lines: _list(json['items'])
            .map(_map)
            .map(
              (row) => RestaurantCartLine(
                item: RestaurantMenuItem(
                  code: _string(row['item_code'] ?? row['item']),
                  name: _string(
                    row['item_name'] ?? row['item_code'] ?? row['item'],
                  ),
                  price: _number(row['rate']),
                  course: '',
                  courseLabel: '',
                  description: _string(row['description']),
                  specialDish: false,
                ),
                quantity: _number(row['qty']),
                comment: _string(row['comment']),
              ),
            )
            .toList(growable: false),
      );

  final RestaurantOrderReceipt receipt;
  final List<RestaurantCartLine> lines;
}

final class RestaurantOrderPage {
  const RestaurantOrderPage({required this.orders, required this.hasMore});
  final List<RestaurantOrderReceipt> orders;
  final bool hasMore;
}

final class RestaurantPaymentLine {
  const RestaurantPaymentLine({required this.mode, required this.amount});
  final String mode;
  final double amount;

  Map<String, Object?> toJson() => {'mode_of_payment': mode, 'amount': amount};
}

final class RestaurantBootstrap {
  const RestaurantBootstrap({
    required this.profile,
    required this.categories,
    required this.rooms,
  });

  final RestaurantPosProfile profile;
  final List<RestaurantMenuCategory> categories;
  final List<RestaurantRoom> rooms;
}

String _string(Object? value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};
