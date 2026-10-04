import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/restaurant/restaurant_controller.dart';
import 'package:tuyubooking/client/restaurant/restaurant_repository.dart';

void main() {
  test('cart combines identical lines and enforces guest bounds', () async {
    final transport = _FakeTransport(_bootstrapResponses());
    final session = EmployeeSession(
      module: EmployeeBusinessModule.restaurant,
      identity: 'employee@example.com',
      transport: transport,
      logout: (_, _) async {},
    );
    final controller = RestaurantController(RestaurantRepository(session));
    await controller.initialize();
    final item = controller.menu.single;

    controller.addConfiguredItem(item: item, quantity: 2, comment: 'Less salt');
    controller.addConfiguredItem(item: item, quantity: 1, comment: 'Less salt');
    controller.setNumberOfGuests(120);

    expect(controller.cart.single.quantity, 3);
    expect(controller.total, 84);
    expect(controller.numberOfGuests, 99);
    expect(controller.canSubmit, isTrue);
    controller.dispose();
    session.dispose();
  });
}

List<EmployeeHttpResponse> _bootstrapResponses() => [
  _json(200, {
    'message': {
      'pos_profile': 'Main POS',
      'branch': 'Shanghai',
      'company': 'Tuyu Restaurant',
      'owner': 'owner@example.com',
    },
  }),
  _json(200, {
    'data': {
      'name': 'Main POS',
      'branch': 'Shanghai',
      'customer': 'Walk-in Customer',
      'currency': 'CNY',
      'payments': [
        {'mode_of_payment': 'Cash'},
      ],
    },
  }),
  _json(200, {
    'message': [
      {'name': 'Main Course', 'label': 'Main Course'},
    ],
  }),
  _json(200, {'message': []}),
  _json(200, {
    'message': {
      'items': [
        {
          'item': 'NOODLES',
          'item_name': 'Noodles',
          'rate': 28,
          'course': 'Main Course',
        },
      ],
    },
  }),
];

EmployeeHttpResponse _json(int statusCode, Object body) => EmployeeHttpResponse(
  statusCode: statusCode,
  headers: const {},
  body: jsonEncode(body),
);

final class _FakeTransport implements EmployeeHttpTransport {
  _FakeTransport(this.responses);
  final List<EmployeeHttpResponse> responses;

  @override
  Future<EmployeeHttpResponse> send(
    EmployeeBusinessModule module,
    String endpoint, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    String? body,
  }) async => responses.removeAt(0);

  @override
  void close() {}
}
