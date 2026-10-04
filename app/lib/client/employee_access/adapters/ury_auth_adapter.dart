import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

final class UryAuthAdapter implements EmployeeAuthAdapter {
  const UryAuthAdapter({this.transportFactory = createPinnedEmployeeTransport});
  final EmployeeTransportFactory transportFactory;

  @override
  EmployeeBusinessModule get module => EmployeeBusinessModule.restaurant;

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
