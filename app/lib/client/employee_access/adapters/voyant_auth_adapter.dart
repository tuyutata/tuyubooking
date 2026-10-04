import 'dart:convert';

import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

final class VoyantAuthAdapter implements EmployeeAuthAdapter {
  const VoyantAuthAdapter({
    this.transportFactory = createPinnedEmployeeTransport,
  });
  final EmployeeTransportFactory transportFactory;

  @override
  EmployeeBusinessModule get module => EmployeeBusinessModule.tour;

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
        '/api/auth/sign-in/email',
        method: 'POST',
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': identifier,
          'password': password,
          'rememberMe': false,
        }),
      );
      final loginBody = jsonObject(response.jsonBody);
      if (!response.isSuccess) throw authenticationFailureFor(response);
      if (loginBody?.containsKey('error') == true) {
        throw const EmployeeAuthenticationException(
          EmployeeAuthenticationFailure.invalidCredentials,
        );
      }
      final status = await transport.send(module, '/api/auth/status');
      if (!status.isSuccess) throw authenticationFailureFor(status);
      return EmployeeSession(
        module: module,
        identity: employeeIdentity(status.jsonBody, identifier),
        transport: transport,
        logout: (client, _) async {
          await client.send(module, '/api/auth/sign-out', method: 'POST');
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
