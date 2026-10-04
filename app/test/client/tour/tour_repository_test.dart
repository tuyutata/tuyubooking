import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';
import 'package:tuyubooking/client/tour/tour_repository.dart';

void main() {
  test('maps Voyant products, departures and filtered booking pages', () async {
    final transport = _FakeTransport([
      _json(200, {
        'data': [
          {'id': 'prod_1', 'name': 'Silk Road', 'status': 'active'},
        ],
        'total': 1,
        'limit': 100,
        'offset': 0,
      }),
      _json(200, {
        'data': [
          {
            'id': 'slot_1',
            'productId': 'prod_1',
            'dateLocal': '2026-09-10',
            'startsAt': '2026-09-10T09:00:00.000Z',
            'timezone': 'Asia/Shanghai',
            'status': 'open',
            'unlimited': false,
            'initialPax': 20,
            'remainingPax': 6,
          },
        ],
      }),
      _json(200, {
        'data': [
          {
            'id': 'book_1',
            'bookingNumber': 'TUYU-1001',
            'status': 'on_hold',
            'contactEmail': 'guest@example.com',
            'sellCurrency': 'CNY',
            'sellAmountCents': 120000,
            'startDate': '2026-09-10',
            'endDate': '2026-09-16',
            'pax': 2,
          },
        ],
        'total': 1,
        'limit': 25,
        'offset': 0,
      }),
    ]);
    final repository = TourRepository(_session(transport));

    final products = await repository.loadProducts();
    final departures = await repository.loadDepartures(productId: 'prod_1');
    final bookings = await repository.loadBookings(
      search: 'TUYU-1001',
      status: 'on_hold',
      productId: 'prod_1',
      dateFrom: '2026-09-01',
      dateTo: '2026-09-30',
    );

    expect(products.items.single.name, 'Silk Road');
    expect(departures.single.remainingPax, 6);
    expect(bookings.items.single.sellAmountCents, 120000);
    expect(transport.calls[1].queryParameters['productId'], 'prod_1');
    expect(transport.calls[2].queryParameters['status'], 'on_hold');
    expect(transport.calls[2].queryParameters['dateFrom'], '2026-09-01');
  });

  test('loads booking detail, items and native travelers', () async {
    final transport = _FakeTransport([
      _json(200, {
        'data': {
          'id': 'book_1',
          'bookingNumber': 'TUYU-1001',
          'status': 'confirmed',
          'sellCurrency': 'CNY',
          'startDate': '2026-09-10',
          'endDate': '2026-09-16',
          'contactFirstName': 'A',
          'contactLastName': 'Guest',
        },
      }),
      _json(200, {
        'data': [
          {
            'id': 'item_1',
            'title': 'Silk Road Tour',
            'status': 'confirmed',
            'itemType': 'service',
            'quantity': 2,
            'productId': 'prod_1',
            'availabilitySlotId': 'slot_1',
          },
        ],
      }),
      _json(200, {
        'data': [
          {
            'id': 'trav_1',
            'firstName': 'A',
            'lastName': 'Guest',
            'participantType': 'adult',
            'isPrimary': true,
          },
        ],
      }),
    ]);
    final repository = TourRepository(_session(transport));

    final bundle = await repository.loadBookingBundle('book_1');

    expect(bundle.booking.contactName, 'A Guest');
    expect(bundle.items.single.availabilitySlotId, 'slot_1');
    expect(bundle.travelers.single.isPrimary, isTrue);
    expect(transport.calls[0].endpoint, '/v1/bookings/book_1');
    expect(transport.calls[2].endpoint, '/v1/bookings/book_1/travelers');
  });

  test('keeps HTTP 202 distinct from a completed booking action', () async {
    final transport = _FakeTransport([
      _json(202, {
        'data': {'approvalId': 'approval_1'},
      }),
      _json(200, {
        'data': {'id': 'book_1', 'status': 'cancelled'},
      }),
    ]);
    final repository = TourRepository(_session(transport));

    final confirm = await repository.confirmBooking('book_1', note: 'Reviewed');
    final cancel = await repository.cancelBooking('book_1');

    expect(confirm, TourActionOutcome.pendingApproval);
    expect(cancel, TourActionOutcome.completed);
    expect(transport.calls.first.method, 'POST');
    expect(jsonDecode(transport.calls.first.body!) as Map<String, Object?>, {
      'note': 'Reviewed',
    });
  });

  test('does not bypass Voyant permission denial', () async {
    final repository = TourRepository(
      _session(
        _FakeTransport([
          _json(403, {'error': 'forbidden'}),
        ]),
      ),
    );
    await expectLater(
      repository.loadProducts(),
      throwsA(
        isA<TourRepositoryException>().having(
          (error) => error.failure,
          'failure',
          TourRepositoryFailure.permissionDenied,
        ),
      ),
    );
  });
}

EmployeeSession _session(EmployeeHttpTransport transport) => EmployeeSession(
  module: EmployeeBusinessModule.tour,
  identity: 'operator@example.com',
  transport: transport,
  logout: (_, _) async {},
);

EmployeeHttpResponse _json(int statusCode, Object body) => EmployeeHttpResponse(
  statusCode: statusCode,
  headers: const {},
  body: jsonEncode(body),
);

final class _Call {
  const _Call(this.endpoint, this.method, this.queryParameters, this.body);
  final String endpoint;
  final String method;
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
    calls.add(_Call(endpoint, method, Map.of(queryParameters), body));
    return responses.removeAt(0);
  }

  @override
  void close() {}
}
