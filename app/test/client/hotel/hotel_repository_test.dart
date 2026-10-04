import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/hotel/hotel_models.dart';
import 'package:tuyubooking/client/hotel/hotel_repository.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

void main() {
  test('maps Kamra front desk and availability contracts', () async {
    final transport = _FakeTransport([
      _json(200, {
        'message': [
          {'name': 'PROP-1', 'property_name': 'Lake Hotel', 'city': 'Hangzhou'},
        ],
      }),
      _json(200, {
        'message': {
          'date': '2026-08-27',
          'arrivals': [
            {
              'name': 'RES-1',
              'guest_name': 'Guest A',
              'room_type': 'King',
              'status': 'Confirmed',
              'check_in_date': '2026-08-27',
              'check_out_date': '2026-08-28',
            },
          ],
          'departures': [],
          'in_house': [],
          'rooms': [
            {
              'name': 'ROOM-101',
              'room_number': '101',
              'room_type': 'King',
              'housekeeping_status': 'Clean',
              'occupancy_status': 'Vacant',
            },
          ],
        },
      }),
      _json(200, {
        'message': {
          'start': '2026-08-27',
          'days': 14,
          'dates': ['2026-08-27'],
          'room_types': [
            {
              'room_type': 'King',
              'room_type_name': 'King Room',
              'total_rooms': 10,
              'cells': [
                {'date': '2026-08-27', 'available': 3, 'rate': 300},
              ],
            },
          ],
        },
      }),
      _json(200, {
        'message': {
          'room_types': [
            {'name': 'King', 'label': 'King Room'},
          ],
          'meal_plans': [],
        },
      }),
    ]);
    final repository = HotelRepository(_session(transport));

    final properties = await repository.loadProperties();
    final snapshot = await repository.loadSnapshot(properties.single.name);
    final availability = await repository.loadAvailability(
      properties.single.name,
      startDate: '2026-08-27',
    );
    final options = await repository.loadBookingOptions(properties.single.name);

    expect(properties.single.displayName, 'Lake Hotel');
    expect(snapshot.arrivals.single.name, 'RES-1');
    expect(snapshot.rooms.single.housekeepingStatus, 'Clean');
    expect(availability.rows.single.cells.single.available, 3);
    expect(options.roomTypes.single.value, 'King');
    expect(transport.calls.every((call) => call.method == 'POST'), isTrue);
  });

  test('forwards native Kamra reservation and room actions', () async {
    final transport = _FakeTransport([
      _json(200, {
        'message': {
          'reservation': {
            'name': 'RES-1',
            'guest_name': 'Guest A',
            'room_type': 'King',
            'status': 'Confirmed',
            'check_in_date': '2026-08-27',
            'check_out_date': '2026-08-28',
          },
          'actions': {'can_check_in': 1, 'can_check_out': 0},
        },
      }),
      _json(200, {
        'message': {'reservation': 'RES-2', 'room': 'ROOM-102'},
      }),
      _json(200, {
        'message': {'ok': true},
      }),
      _json(200, {
        'message': {'ok': true},
      }),
      _json(200, {
        'message': {'ok': true},
      }),
    ]);
    final repository = HotelRepository(_session(transport));

    final detail = await repository.loadReservationDetail('RES-1');
    final receipt = await repository.createBooking(
      'PROP-1',
      const HotelBookingRequest(
        guestName: 'Guest B',
        roomType: 'King',
        checkInDate: '2026-08-29',
        checkOutDate: '2026-08-30',
        adults: 2,
        children: 0,
      ),
    );
    await repository.checkIn('RES-1');
    await repository.checkOut('RES-1');
    await repository.updateHousekeeping('ROOM-101', 'Inspected');

    expect(detail.canCheckIn, isTrue);
    expect(receipt.reservation, 'RES-2');
    expect(transport.calls[1].endpoint, '/api/method/kamra.api.create_booking');
    final booking =
        jsonDecode(transport.calls[1].body!) as Map<String, Object?>;
    expect(booking['property'], 'PROP-1');
    expect(booking['guest_name'], 'Guest B');
    expect(
      transport.calls.last.endpoint,
      '/api/method/kamra.api.set_housekeeping_status',
    );
  });

  test('preserves Kamra permission denial', () async {
    final repository = HotelRepository(
      _session(
        _FakeTransport([
          _json(403, {'exc_type': 'PermissionError'}),
        ]),
      ),
    );
    await expectLater(
      repository.loadProperties(),
      throwsA(
        isA<HotelRepositoryException>().having(
          (error) => error.failure,
          'failure',
          HotelRepositoryFailure.permissionDenied,
        ),
      ),
    );
  });
}

EmployeeSession _session(EmployeeHttpTransport transport) => EmployeeSession(
  module: EmployeeBusinessModule.hotel,
  identity: 'frontdesk@example.com',
  transport: transport,
  logout: (_, _) async {},
);

EmployeeHttpResponse _json(int statusCode, Object body) => EmployeeHttpResponse(
  statusCode: statusCode,
  headers: const {},
  body: jsonEncode(body),
);

final class _Call {
  const _Call(this.endpoint, this.method, this.body);
  final String endpoint;
  final String method;
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
    calls.add(_Call(endpoint, method, body));
    return responses.removeAt(0);
  }

  @override
  void close() {}
}
