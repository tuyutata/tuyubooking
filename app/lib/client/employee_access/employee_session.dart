import 'dart:convert';

import 'package:tuyubooking/shared/localization/bilingual_text.dart';

enum EmployeeBusinessModule {
  hotel(
    route: '/hotel',
    title: BilingualCopy(zh: '酒店', en: 'Hotel'),
    identifier: BilingualCopy(zh: '邮箱或用户名', en: 'Email or username'),
  ),
  restaurant(
    route: '/restaurant',
    title: BilingualCopy(zh: '餐厅', en: 'Restaurant'),
    identifier: BilingualCopy(zh: '邮箱或用户名', en: 'Email or username'),
  ),
  tour(
    route: '/tour',
    title: BilingualCopy(zh: '旅行团活动', en: 'Tours & activities'),
    identifier: BilingualCopy(zh: '邮箱', en: 'Email'),
  ),
  ticket(
    route: '/ticket',
    title: BilingualCopy(zh: '票务', en: 'Ticketing'),
    identifier: BilingualCopy(zh: '邮箱', en: 'Email'),
  );

  const EmployeeBusinessModule({
    required this.route,
    required this.title,
    required this.identifier,
  });

  final String route;
  final BilingualCopy title;
  final BilingualCopy identifier;

  static EmployeeBusinessModule? fromRoute(String route) {
    for (final module in values) {
      if (module.route == route) return module;
    }
    return null;
  }
}

final class EmployeeHttpResponse {
  const EmployeeHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Object? get jsonBody {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

abstract interface class EmployeeHttpTransport {
  Future<EmployeeHttpResponse> send(
    EmployeeBusinessModule module,
    String endpoint, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    String? body,
  });

  void close();
}

typedef EmployeeLogout =
    Future<void> Function(
      EmployeeHttpTransport transport,
      Map<String, String> authorizationHeaders,
    );

/// Module-scoped process-only session. It never contains the password.
final class EmployeeSession {
  EmployeeSession({
    required this.module,
    required this.identity,
    required this.transport,
    required this.logout,
    Map<String, String> authorizationHeaders = const {},
  }) : _authorizationHeaders = Map.unmodifiable(authorizationHeaders);

  final EmployeeBusinessModule module;
  final String identity;
  final EmployeeHttpTransport transport;
  final EmployeeLogout logout;
  final Map<String, String> _authorizationHeaders;
  bool _closed = false;

  Future<EmployeeHttpResponse> request(
    String endpoint, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    String? body,
  }) {
    if (_closed) throw StateError('Employee session is closed');
    return transport.send(
      module,
      endpoint,
      method: method,
      headers: {..._authorizationHeaders, ...headers},
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<void> signOut() async {
    if (_closed) return;
    _closed = true;
    try {
      await logout(transport, _authorizationHeaders);
    } finally {
      transport.close();
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    transport.close();
  }
}
