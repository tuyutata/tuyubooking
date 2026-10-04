import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';
import 'package:tuyubooking/client/restaurant/restaurant_repository.dart';

void main() {
  test('maps URY profile, menu, table and sync_order contracts', () async {
    final transport = _FakeTransport([
      _json(200, {
        'message': {
          'pos_profile': 'Main POS',
          'branch': 'Shanghai',
          'company': 'Tuyu Restaurant',
          'cashier': 'cashier@example.com',
          'waiter': 'waiter@example.com',
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
            {'mode_of_payment': 'Card'},
          ],
        },
      }),
      _json(200, {
        'message': [
          {'name': 'Main Course', 'label': 'Main Course'},
        ],
      }),
      _json(200, {
        'message': [
          {'name': 'Dining Hall', 'branch': 'Shanghai'},
        ],
      }),
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
      _json(200, {
        'message': [
          {
            'name': 'Table 1',
            'restaurant_room': 'Dining Hall',
            'occupied': 0,
            'no_of_seats': 4,
          },
        ],
      }),
      _json(200, {
        'message': {'name': 'POS-INV-1', 'status': 'Draft', 'grand_total': 56},
      }),
    ]);
    final session = _session(transport);
    final repository = RestaurantRepository(session);

    final bootstrap = await repository.loadBootstrap();
    final menu = await repository.loadMenu(
      profile: bootstrap.profile,
      orderType: RestaurantOrderType.dineIn,
      room: 'Dining Hall',
    );
    final tables = await repository.loadTables('Dining Hall');
    final receipt = await repository.submitOrder(
      profile: bootstrap.profile,
      orderType: RestaurantOrderType.dineIn,
      lines: [RestaurantCartLine(item: menu.single, quantity: 2)],
      numberOfGuests: 2,
      room: 'Dining Hall',
      table: 'Table 1',
    );

    expect(bootstrap.profile.defaultCustomer, 'Walk-in Customer');
    expect(bootstrap.profile.paymentModes, ['Cash', 'Card']);
    expect(menu.single.code, 'NOODLES');
    expect(tables.single.seats, 4);
    expect(receipt.name, 'POS-INV-1');
    final syncCall = transport.calls.last;
    expect(
      syncCall.endpoint,
      '/api/method/ury.ury.doctype.ury_order.ury_order.sync_order',
    );
    final syncBody = jsonDecode(syncCall.body!) as Map<String, Object?>;
    expect(syncBody['customer'], 'Walk-in Customer');
    expect(syncBody['table'], 'Table 1');
    expect((syncBody['items'] as List).length, 1);
    session.dispose();
  });

  test('preserves URY permission denial instead of bypassing it', () async {
    final transport = _FakeTransport([
      _json(403, {'exc_type': 'PermissionError'}),
    ]);
    final repository = RestaurantRepository(_session(transport));
    const profile = RestaurantPosProfile(
      name: 'Main POS',
      branch: 'Shanghai',
      company: 'Tuyu Restaurant',
      defaultCustomer: 'Walk-in Customer',
      currency: 'CNY',
      cashier: '',
      waiter: '',
      owner: '',
      paymentModes: ['Cash'],
    );

    await expectLater(
      repository.loadMenu(
        profile: profile,
        orderType: RestaurantOrderType.takeAway,
      ),
      throwsA(
        isA<RestaurantRepositoryException>().having(
          (error) => error.failure,
          'failure',
          RestaurantRepositoryFailure.permissionDenied,
        ),
      ),
    );
  });

  test(
    'checks POS Opening and forwards split payments to make_invoice',
    () async {
      final transport = _FakeTransport([
        _json(200, {
          'message': [
            {'name': 'POS-OPEN-1', 'pos_profile': 'Main POS'},
          ],
        }),
        _json(200, {
          'message': {'name': 'POS-INV-1'},
        }),
      ]);
      final repository = RestaurantRepository(_session(transport));
      const profile = RestaurantPosProfile(
        name: 'Main POS',
        branch: 'Shanghai',
        company: 'Tuyu Restaurant',
        defaultCustomer: 'Walk-in Customer',
        currency: 'CNY',
        cashier: 'cashier@example.com',
        waiter: 'waiter@example.com',
        owner: 'owner@example.com',
        paymentModes: ['Cash', 'Card'],
      );
      const order = RestaurantOrderReceipt(
        name: 'POS-INV-1',
        status: 'Unbilled',
        total: 100,
        roundedTotal: 100,
        customer: 'Walk-in Customer',
        table: 'Table 1',
        modified: '2026-08-27 10:00:00',
      );

      await repository.makePayment(
        profile: profile,
        order: order,
        payments: const [
          RestaurantPaymentLine(mode: 'Cash', amount: 60),
          RestaurantPaymentLine(mode: 'Card', amount: 40),
        ],
      );

      expect(
        transport.calls.first.endpoint,
        '/api/method/erpnext.selling.page.point_of_sale.point_of_sale.check_opening_entry',
      );
      expect(
        transport.calls.last.endpoint,
        '/api/method/ury.ury.doctype.ury_order.ury_order.make_invoice',
      );
      final paymentBody =
          jsonDecode(transport.calls.last.body!) as Map<String, Object?>;
      expect((paymentBody['payments'] as List).length, 2);
    },
  );
}

EmployeeSession _session(EmployeeHttpTransport transport) => EmployeeSession(
  module: EmployeeBusinessModule.restaurant,
  identity: 'employee@example.com',
  transport: transport,
  logout: (_, _) async {},
);

EmployeeHttpResponse _json(int statusCode, Object body) => EmployeeHttpResponse(
  statusCode: statusCode,
  headers: const {},
  body: jsonEncode(body),
);

final class _Call {
  const _Call(this.endpoint, this.queryParameters, this.body);
  final String endpoint;
  final Map<String, String> queryParameters;
  final String? body;
}

final class _FakeTransport implements EmployeeHttpTransport {
  _FakeTransport(this.responses);

  final List<EmployeeHttpResponse> responses;
  final List<_Call> calls = [];

  @override
  Future<EmployeeHttpResponse> send(
    EmployeeBusinessModule module,
    String endpoint, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    String? body,
  }) async {
    calls.add(_Call(endpoint, Map.of(queryParameters), body));
    return responses.removeAt(0);
  }

  @override
  void close() {}
}
