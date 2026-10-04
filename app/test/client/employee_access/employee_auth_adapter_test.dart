import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/adapters/hi_events_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/kamra_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/ury_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/voyant_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_login_page.dart';

void main() {
  const profile = EmployeeHostProfile(
    address: '192.168.1.20',
    port: 58460,
    instanceId: 'merchant-1',
    merchantName: '途遇测试商家',
    certificateFingerprint: 'abc123',
    routes: ['/hotel', '/restaurant', '/tour', '/ticket'],
  );

  for (final module in EmployeeBusinessModule.values) {
    test('${module.name} rejects invalid upstream credentials and closes its transport', () async {
      final transport = _FakeTransport([_json(401, {'error': 'denied'})]);
      final EmployeeAuthAdapter adapter = switch (module) {
        EmployeeBusinessModule.hotel => KamraAuthAdapter(transportFactory: (_) => transport),
        EmployeeBusinessModule.restaurant => UryAuthAdapter(transportFactory: (_) => transport),
        EmployeeBusinessModule.tour => VoyantAuthAdapter(transportFactory: (_) => transport),
        EmployeeBusinessModule.ticket => HiEventsAuthAdapter(transportFactory: (_) => transport),
      };
      await expectLater(adapter.signIn(profile: profile, identifier: 'employee', password: 'fixture'),
        throwsA(isA<EmployeeAuthenticationException>().having(
          (error) => error.failure, 'failure', EmployeeAuthenticationFailure.invalidCredentials)));
      expect(transport.closed, isTrue);
      expect(transport.calls.single.module, module);
    });
  }

  testWidgets('duplicate submission is ignored and a late session is disposed after leaving login', (tester) async {
    final adapter = _PendingAdapter();
    await tester.pumpWidget(MaterialApp(home: EmployeeLoginPage(
      profile: profile, module: EmployeeBusinessModule.restaurant, adapter: adapter)));
    await tester.enterText(find.byType(TextField).first, 'employee');
    await tester.enterText(find.byType(TextField).last, 'fixture');
    final password = tester.widget<TextField>(find.byType(TextField).last);
    password.onSubmitted!('fixture');
    password.onSubmitted!('fixture');
    await tester.pump();
    expect(adapter.calls, 1);
    expect(password.controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    final transport = _FakeTransport([]);
    adapter.response.complete(EmployeeSession(
      module: EmployeeBusinessModule.restaurant, identity: 'employee',
      transport: transport, logout: (_, _) async {}));
    await tester.pump();
    expect(transport.closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login cannot submit an account to a disabled business module', (tester) async {
    final adapter = _PendingAdapter();
    final hotelOnly = EmployeeHostProfile(
      address: profile.address, port: profile.port, instanceId: profile.instanceId,
      merchantName: profile.merchantName, certificateFingerprint: profile.certificateFingerprint,
      routes: const ['/hotel']);
    await tester.pumpWidget(MaterialApp(home: EmployeeLoginPage(
      profile: hotelOnly, module: EmployeeBusinessModule.restaurant, adapter: adapter)));
    await tester.enterText(find.byType(TextField).first, 'employee');
    await tester.enterText(find.byType(TextField).last, 'fixture');
    tester.widget<TextField>(find.byType(TextField).last).onSubmitted!('fixture');
    await tester.pump();
    expect(adapter.calls, 0);
    expect(find.text('The business subsystem is unavailable. Try again shortly.'), findsOneWidget);
  });

  test('Kamra and URY retain separate Frappe employee sessions', () async {
    final hotel = _FakeTransport([
      _json(200, {'message': 'Logged In', 'full_name': 'Hotel Employee'}),
      _json(200, {'message': 'hotel-csrf'}),
    ]);
    final restaurant = _FakeTransport([
      _json(200, {'message': 'Logged In', 'full_name': 'Restaurant Employee'}),
      _json(200, {'message': 'restaurant-csrf'}),
    ]);
    final hotelSession = await KamraAuthAdapter(
      transportFactory: (_) => hotel,
    ).signIn(profile: profile, identifier: 'hotel', password: 'secret');
    final restaurantSession = await UryAuthAdapter(
      transportFactory: (_) => restaurant,
    ).signIn(profile: profile, identifier: 'restaurant', password: 'secret');

    expect(hotel.calls.first.endpoint, '/api/method/login');
    expect(hotel.calls.first.module, EmployeeBusinessModule.hotel);
    expect(restaurant.calls.first.module, EmployeeBusinessModule.restaurant);
    expect(hotelSession.identity, 'Hotel Employee');
    expect(restaurantSession.identity, 'Restaurant Employee');
    hotelSession.dispose();
    restaurantSession.dispose();
  });

  test('Voyant verifies Better Auth status after sign in', () async {
    final transport = _FakeTransport([
      _json(200, {'redirect': false}),
      _json(200, {
        'user': {'name': 'Tour Employee', 'email': 'tour@example.com'},
      }),
    ]);
    final session = await VoyantAuthAdapter(transportFactory: (_) => transport)
        .signIn(
          profile: profile,
          identifier: 'tour@example.com',
          password: 'secret',
        );

    expect(transport.calls[0].endpoint, '/api/auth/sign-in/email');
    expect(transport.calls[1].endpoint, '/api/auth/status');
    expect(session.identity, 'Tour Employee');
    session.dispose();
  });

  test('Hi.Events keeps its JWT in the module session only', () async {
    final transport = _FakeTransport([
      _json(200, {
        'data': {
          'token': 'local-jwt',
          'user': {'name': 'Ticket Employee'},
        },
      }),
      _json(200, {'ok': true}),
    ]);
    final session =
        await HiEventsAuthAdapter(transportFactory: (_) => transport).signIn(
          profile: profile,
          identifier: 'ticket@example.com',
          password: 'secret123',
        );
    await session.request('/events');

    expect(transport.calls.first.endpoint, '/auth/login');
    expect(transport.calls.last.headers['Authorization'], 'Bearer local-jwt');
    expect(session.identity, 'Ticket Employee');
    session.dispose();
  });
}

EmployeeHttpResponse _json(int statusCode, Object body) => EmployeeHttpResponse(
  statusCode: statusCode,
  headers: const {},
  body: jsonEncode(body),
);

final class _RequestRecord {
  const _RequestRecord(this.module, this.endpoint, this.headers);
  final EmployeeBusinessModule module;
  final String endpoint;
  final Map<String, String> headers;
}

final class _FakeTransport implements EmployeeHttpTransport {
  _FakeTransport(this.responses);
  final List<EmployeeHttpResponse> responses;
  final List<_RequestRecord> calls = [];
  bool closed = false;

  @override
  Future<EmployeeHttpResponse> send(
    EmployeeBusinessModule module,
    String endpoint, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    String? body,
  }) async {
    calls.add(_RequestRecord(module, endpoint, Map.of(headers)));
    return responses.removeAt(0);
  }

  @override
  void close() { closed = true; }
}

final class _PendingAdapter implements EmployeeAuthAdapter {
  int calls = 0;
  final response = Completer<EmployeeSession>();
  @override EmployeeBusinessModule get module => EmployeeBusinessModule.restaurant;
  @override Future<EmployeeSession> signIn({required EmployeeHostProfile profile,
      required String identifier, required String password}) {
    calls += 1;
    return response.future;
  }
}
