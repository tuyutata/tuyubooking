import 'dart:convert';

import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

final class HiEventsAuthAdapter implements EmployeeAuthAdapter {
  const HiEventsAuthAdapter({
    this.transportFactory = createPinnedEmployeeTransport,
  });
  final EmployeeTransportFactory transportFactory;

  @override
  EmployeeBusinessModule get module => EmployeeBusinessModule.ticket;

  @override
  Future<EmployeeSession> signIn({
    required EmployeeHostProfile profile,
    required String identifier,
    required String password,
  }) async {
    final transport = transportFactory(profile);
    try {
      final response = await transport.send(
        module,
        '/auth/login',
        method: 'POST',
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': identifier, 'password': password}),
      );
      if (!response.isSuccess) throw authenticationFailureFor(response);
      final payload = unwrapData(response.jsonBody);
      final token = payload?['token'];
      if (token is! String || token.isEmpty) {
        throw const EmployeeAuthenticationException(
          EmployeeAuthenticationFailure.invalidResponse,
        );
      }
      final authorization = {'Authorization': 'Bearer $token'};
      return EmployeeSession(
        module: module,
        identity: employeeIdentity(payload, identifier),
        transport: transport,
        authorizationHeaders: authorization,
        logout: (client, headers) async {
          await client.send(
            module,
            '/auth/logout',
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
}
