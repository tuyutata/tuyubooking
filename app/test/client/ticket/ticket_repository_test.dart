import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';
import 'package:tuyubooking/client/ticket/ticket_repository.dart';

void main() {
  test('parses native Hi.Events ticket values only', () {
    expect(parseHiEventsTicketCode('A-ABC123'), 'A-ABC123');
    expect(
      parseHiEventsTicketCode('https://tickets.example/product/42/A-ABC123'),
      'A-ABC123',
    );
    expect(parseHiEventsTicketCode('https://example.com/not-a-ticket'), isNull);
  });

  test('maps event, stats and attendee pagination contracts', () async {
    final transport = _FakeTransport([
      _json(200, {
        'data': [
          {
            'id': 42,
            'title': 'Travel Expo',
            'start_date': '2026-09-10T09:00:00Z',
            'end_date': '2026-09-10T18:00:00Z',
            'status': 'LIVE',
            'statistics': {'attendees_registered': 120},
          },
        ],
        'meta': {'total': 1, 'current_page': 1, 'per_page': 50},
      }),
      _json(200, {
        'data': {'total_checked_in_attendees': 35},
      }),
      _json(200, {
        'data': [
          {
            'id': 7,
            'event_id': 42,
            'order_id': 9,
            'product_id': 3,
            'public_id': 'A-PUBLIC1',
            'short_id': 'A-SHORT1',
            'first_name': 'A',
            'last_name': 'Guest',
            'email': 'guest@example.com',
            'status': 'ACTIVE',
            'check_ins': [],
          },
        ],
        'meta': {'total': 1, 'current_page': 1, 'per_page': 30},
      }),
    ]);
    final repository = TicketRepository(_session(transport));

    final events = await repository.loadEvents();
    final stats = await repository.loadCheckInStats('42');
    final attendees = await repository.loadAttendees('42', query: 'Guest');

    expect(events.items.single.attendeesRegistered, 120);
    expect(stats.totalCheckedIn, 35);
    expect(attendees.items.single.publicId, 'A-PUBLIC1');
    expect(transport.calls.last.queryParameters['query'], 'Guest');
    expect(transport.calls.last.endpoint, '/events/42/attendees');
  });

  test('resolves short id before submitting authenticated check-in', () async {
    final transport = _FakeTransport([
      _json(200, {
        'data': [
          {
            'id': 7,
            'event_id': 42,
            'order_id': 9,
            'product_id': 3,
            'public_id': 'A-PUBLIC1',
            'short_id': 'A-SHORT1',
            'first_name': 'A',
            'last_name': 'Guest',
            'status': 'ACTIVE',
            'check_ins': [],
          },
        ],
        'meta': {'total': 1},
      }),
      _json(200, {
        'data': {
          'id': 7,
          'event_id': 42,
          'order_id': 9,
          'product_id': 3,
          'public_id': 'A-PUBLIC1',
          'short_id': 'A-SHORT1',
          'first_name': 'A',
          'last_name': 'Guest',
          'status': 'ACTIVE',
          'checked_in_at': '2026-09-10T09:05:00Z',
        },
      }),
    ]);
    final repository = TicketRepository(_session(transport));

    final attendee = await repository.findAttendee('42', 'A-SHORT1');
    final updated = await repository.changeCheckIn(
      '42',
      attendee!.publicId,
      TicketCheckAction.checkIn,
    );

    expect(updated.isCheckedIn, isTrue);
    expect(
      transport.calls.last.endpoint,
      '/events/42/attendees/A-PUBLIC1/check_in',
    );
    expect(jsonDecode(transport.calls.last.body!) as Map<String, Object?>, {
      'action': 'check_in',
    });
  });

  test('preserves upstream duplicate check-in conflict', () async {
    final repository = TicketRepository(
      _session(
        _FakeTransport([
          _json(409, {'message': 'already checked in'}),
        ]),
      ),
    );
    await expectLater(
      repository.changeCheckIn('42', 'A-PUBLIC1', TicketCheckAction.checkIn),
      throwsA(
        isA<TicketRepositoryException>().having(
          (error) => error.failure,
          'failure',
          TicketRepositoryFailure.conflict,
        ),
      ),
    );
  });
}

EmployeeSession _session(EmployeeHttpTransport transport) => EmployeeSession(
  module: EmployeeBusinessModule.ticket,
  identity: 'checkin@example.com',
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
