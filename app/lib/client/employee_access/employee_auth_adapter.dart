import 'dart:convert';

import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

enum EmployeeAuthenticationFailure {
  invalidCredentials,
  serviceUnavailable,
  invalidResponse,
}

final class EmployeeAuthenticationException implements Exception {
  const EmployeeAuthenticationException(this.failure);
  final EmployeeAuthenticationFailure failure;
}

typedef EmployeeTransportFactory =
    EmployeeHttpTransport Function(EmployeeHostProfile profile);

EmployeeHttpTransport createPinnedEmployeeTransport(
  EmployeeHostProfile profile,
) => PinnedEmployeeHttpTransport(profile);

abstract interface class EmployeeAuthAdapter {
  EmployeeBusinessModule get module;

  Future<EmployeeSession> signIn({
    required EmployeeHostProfile profile,
    required String identifier,
    required String password,
  });
}

bool isCredentialFailure(int statusCode) =>
    statusCode == 400 ||
    statusCode == 401 ||
    statusCode == 403 ||
    statusCode == 422;

Map<String, Object?>? jsonObject(Object? value) {
  if (value is! Map) return null;
  return value.cast<String, Object?>();
}

Map<String, Object?>? unwrapData(Object? value) {
  final object = jsonObject(value);
  if (object == null) return null;
  return jsonObject(object['data']) ?? object;
}

String employeeIdentity(Object? value, String fallback) {
  final object = unwrapData(value);
  final user = jsonObject(object?['user']);
  for (final candidate in [
    user?['name'],
    user?['full_name'],
    user?['email'],
    object?['full_name'],
    object?['email'],
  ]) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return fallback;
}

EmployeeAuthenticationException authenticationFailureFor(
  EmployeeHttpResponse response,
) => EmployeeAuthenticationException(
  isCredentialFailure(response.statusCode)
      ? EmployeeAuthenticationFailure.invalidCredentials
      : EmployeeAuthenticationFailure.serviceUnavailable,
);

Future<EmployeeSession> signInToFrappe({
  required EmployeeBusinessModule module,
  required EmployeeHostProfile profile,
  required String identifier,
  required String password,
  required EmployeeTransportFactory transportFactory,
}) async {
  final transport = transportFactory(profile);
  try {
    final response = await transport.send(
      module,
      '/api/method/login',
      method: 'POST',
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'usr': identifier, 'pwd': password}),
    );
    if (!response.isSuccess) throw authenticationFailureFor(response);
    final csrfResponse = await transport.send(
      module,
      '/api/method/frappe.sessions.get_csrf_token',
      headers: const {'Accept': 'application/json'},
    );
    final csrfToken = jsonObject(csrfResponse.jsonBody)?['message'];
    if (!csrfResponse.isSuccess || csrfToken is! String || csrfToken.isEmpty) {
      throw const EmployeeAuthenticationException(
        EmployeeAuthenticationFailure.invalidResponse,
      );
    }
    final sessionHeaders = {'X-Frappe-CSRF-Token': csrfToken};
    return EmployeeSession(
      module: module,
      identity: employeeIdentity(response.jsonBody, identifier),
      transport: transport,
      authorizationHeaders: sessionHeaders,
      logout: (client, headers) async {
        await client.send(
          module,
          '/api/method/logout',
          method: 'POST',
          headers: headers,
        );
      },
    );
  } on EmployeeAuthenticationException {
    transport.close();
    rethrow;
  } on Object {
    transport.close();
    throw const EmployeeAuthenticationException(
      EmployeeAuthenticationFailure.serviceUnavailable,
    );
  }
}
