import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

final class KamraAuthAdapter implements EmployeeAuthAdapter {
  const KamraAuthAdapter({
    this.transportFactory = createPinnedEmployeeTransport,
  });
  final EmployeeTransportFactory transportFactory;

  @override
  EmployeeBusinessModule get module => EmployeeBusinessModule.hotel;

  @override
  Future<EmployeeSession> signIn({
    required EmployeeHostProfile profile,
    required String identifier,
    required String password,
  }) => signInToFrappe(
    module: module,
    profile: profile,
    identifier: identifier,
    password: password,
    transportFactory: transportFactory,
  );
}
