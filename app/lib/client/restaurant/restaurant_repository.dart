import 'dart:convert';

import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';

enum RestaurantRepositoryFailure {
  unavailable,
  invalidResponse,
  permissionDenied,
  orderConflict,
  posOpeningRequired,
  paymentMismatch,
}

final class RestaurantRepositoryException implements Exception {
  const RestaurantRepositoryException(this.failure);
  final RestaurantRepositoryFailure failure;
}

/// Thin URY adapter. Pricing, permissions and invoice rules remain in URY.
final class RestaurantRepository {
  const RestaurantRepository(this.session);

  final EmployeeSession session;

  Future<RestaurantBootstrap> loadBootstrap() async {
    final limited = _object(await _rpc('ury.ury_pos.api.getPosProfile'));
    final profileName = limited['pos_profile']?.toString() ?? '';
    if (profileName.isEmpty) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.invalidResponse,
      );
    }
    final fullResponse = await _request(
      '/api/resource/POS Profile/$profileName',
    );
    final full = _object(_object(fullResponse)['data']);
    final profile = RestaurantPosProfile.fromUpstream(limited, full);
    if (profile.defaultCustomer.isEmpty) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.invalidResponse,
      );
    }
    final categoryRows = _list(await _rpc('ury.ury_pos.api.getMenuCourses'));
    final roomRows = _list(
      await _rpc(
        'frappe.client.get_list',
        method: 'POST',
        parameters: {
          'doctype': 'URY Room',
          'fields': ['name', 'branch'],
          'filters': [
            ['branch', '=', profile.branch],
          ],
          'limit_page_length': 0,
        },
      ),
    );
    return RestaurantBootstrap(
      profile: profile,
      categories: categoryRows
          .map(_object)
          .map(RestaurantMenuCategory.fromJson)
          .toList(growable: false),
      rooms: roomRows
          .map(_object)
          .map(RestaurantRoom.fromJson)
          .toList(growable: false),
    );
  }

  Future<List<RestaurantMenuItem>> loadMenu({
    required RestaurantPosProfile profile,
    required RestaurantOrderType orderType,
    String? room,
  }) async {
    final message = _object(
      await _rpc(
        'ury.ury_pos.api.getRestaurantMenu',
        parameters: {
          'pos_profile': profile.name,
          'order_type': orderType.upstreamValue,
          if (room != null && room.isNotEmpty) 'room': room,
        },
      ),
    );
    return _list(
      message['items'],
    ).map(_object).map(RestaurantMenuItem.fromJson).toList(growable: false);
  }

  Future<List<RestaurantTable>> loadTables(String room) async {
    final rows = _list(
      await _rpc(
        'frappe.client.get_list',
        method: 'POST',
        parameters: {
          'doctype': 'URY Table',
          'fields': ['name', 'restaurant_room', 'occupied', 'no_of_seats'],
          'filters': [
            ['restaurant_room', '=', room],
          ],
          'limit_page_length': 0,
        },
      ),
    );
    return rows
        .map(_object)
        .map(RestaurantTable.fromJson)
        .toList(growable: false);
  }

  Future<RestaurantItemOptions> loadItemOptions(
    RestaurantMenuItem item,
    List<RestaurantMenuItem> menu,
  ) async {
    final response = _object(await _request('/api/resource/Item/${item.code}'));
    final document = _object(response['data']);
    final byCode = {for (final row in menu) row.code: row};
    List<RestaurantMenuItem> resolve(String field) => _list(document[field])
        .map(_object)
        .map((row) => row['item']?.toString() ?? '')
        .where(byCode.containsKey)
        .map((code) => byCode[code]!)
        .toList(growable: false);
    return RestaurantItemOptions(
      variants: resolve('custom_pos_item_variants'),
      addOns: resolve('custom_pos_add_on_items'),
    );
  }

  Future<RestaurantOrderReceipt> submitOrder({
    required RestaurantPosProfile profile,
    required RestaurantOrderType orderType,
    required List<RestaurantCartLine> lines,
    required int numberOfGuests,
    String? room,
    String? table,
    String? comments,
    RestaurantOrderReceipt? existingOrder,
  }) async {
    final message = await _rpc(
      'ury.ury.doctype.ury_order.ury_order.sync_order',
      method: 'POST',
      parameters: {
        'items': lines
            .map(
              (line) => {
                'item': line.item.code,
                'item_name': line.item.name,
                'rate': line.item.price,
                'qty': line.quantity,
                if (line.comment.isNotEmpty) 'comment': line.comment,
              },
            )
            .toList(growable: false),
        'cashier': profile.cashier,
        'owner': profile.owner,
        'mode_of_payment': '',
        'customer': profile.defaultCustomer,
        'no_of_pax': numberOfGuests,
        'last_invoice': existingOrder?.name,
        'waiter': profile.waiter,
        'pos_profile': profile.name,
        'invoice': existingOrder?.name,
        if (existingOrder?.modified.isNotEmpty == true)
          'last_modified_time': existingOrder!.modified,
        'order_type': orderType.upstreamValue,
        'room': ?room,
        'table': ?table,
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      },
    );
    final order = _object(message);
    if (order['status'] == 'Failure') {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.orderConflict,
      );
    }
    final receipt = RestaurantOrderReceipt.fromJson(order);
    if (receipt.name.isEmpty) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.invalidResponse,
      );
    }
    return receipt;
  }

  Future<RestaurantOrderRecord?> loadTableOrder(String table) async {
    final message = await _rpc(
      'ury.ury.doctype.ury_order.ury_order.get_order_invoice',
      parameters: {'table': table},
    );
    if (message == null) return null;
    return RestaurantOrderRecord.fromJson(_object(message));
  }

  Future<RestaurantOrderPage> loadOrders({
    required String status,
    int page = 1,
    int limit = 10,
  }) async {
    final message = _object(
      await _rpc(
        'ury.ury_pos.api.getPosInvoice',
        parameters: {
          'status': status,
          'limit': limit,
          'limit_start': (page - 1) * limit,
        },
      ),
    );
    return RestaurantOrderPage(
      orders: _list(message['data'])
          .map(_object)
          .map(RestaurantOrderReceipt.fromJson)
          .toList(growable: false),
      hasMore: message['next'] == true || message['next'] == 1,
    );
  }

  Future<List<RestaurantCartLine>> loadOrderItems(String invoice) async {
    final message = _list(
      await _rpc(
        'ury.ury_pos.api.getPosInvoiceItems',
        parameters: {'invoice': invoice},
      ),
    );
    final rows = message.isEmpty ? const <Object?>[] : _list(message.first);
    return rows
        .map(_object)
        .map(
          (row) => RestaurantCartLine(
            item: RestaurantMenuItem(
              code: row['item_code']?.toString() ?? '',
              name: row['item_name']?.toString() ?? '',
              price: _asDouble(row['rate']),
              course: '',
              courseLabel: '',
              description: '',
              specialDish: false,
            ),
            quantity: _asDouble(row['qty']),
          ),
        )
        .toList(growable: false);
  }

  Future<void> makePayment({
    required RestaurantPosProfile profile,
    required RestaurantOrderReceipt order,
    required List<RestaurantPaymentLine> payments,
  }) async {
    final total = payments.fold<double>(0, (sum, line) => sum + line.amount);
    if (payments.isEmpty || total + 0.005 < order.roundedTotal) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.paymentMismatch,
      );
    }
    final opening = await _rpc(
      'erpnext.selling.page.point_of_sale.point_of_sale.check_opening_entry',
    );
    final hasOpening = opening is List && opening.isNotEmpty;
    if (!hasOpening) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.posOpeningRequired,
      );
    }
    await _rpc(
      'ury.ury.doctype.ury_order.ury_order.make_invoice',
      method: 'POST',
      parameters: {
        'additionalDiscount': null,
        'cashier': profile.cashier,
        'customer': order.customer.isEmpty
            ? profile.defaultCustomer
            : order.customer,
        'invoice': order.name,
        'owner': profile.owner,
        'payments': payments
            .map((line) => line.toJson())
            .toList(growable: false),
        'pos_profile': profile.name,
        'table': order.table.isEmpty ? null : order.table,
      },
    );
  }

  Future<Object?> _rpc(
    String methodName, {
    String method = 'GET',
    Map<String, Object?> parameters = const {},
  }) async {
    final upperMethod = method.toUpperCase();
    final response = await _request(
      '/api/method/$methodName',
      method: upperMethod,
      queryParameters: upperMethod == 'GET'
          ? parameters.map(
              (key, value) =>
                  MapEntry(key, value is String ? value : jsonEncode(value)),
            )
          : const {},
      body: upperMethod == 'GET' ? null : jsonEncode(parameters),
    );
    return _object(response)['message'];
  }

  Future<Object?> _request(
    String endpoint, {
    String method = 'GET',
    Map<String, String> queryParameters = const {},
    String? body,
  }) async {
    final response = await session.request(
      endpoint,
      method: method,
      queryParameters: queryParameters,
      headers: {
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.permissionDenied,
      );
    }
    if (!response.isSuccess) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.unavailable,
      );
    }
    final decoded = response.jsonBody;
    if (decoded == null) {
      throw const RestaurantRepositoryException(
        RestaurantRepositoryFailure.invalidResponse,
      );
    }
    return decoded;
  }

  Map<String, Object?> _object(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    throw const RestaurantRepositoryException(
      RestaurantRepositoryFailure.invalidResponse,
    );
  }

  List<Object?> _list(Object? value) {
    if (value is List) return value.cast<Object?>();
    throw const RestaurantRepositoryException(
      RestaurantRepositoryFailure.invalidResponse,
    );
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
