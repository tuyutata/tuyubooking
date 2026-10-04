import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tuyubooking/host/host_app.dart';
import 'package:tuyubooking/host/infrastructure/runtime/packaged_smoke.dart';
import 'package:tuyubooking/shared/application_target.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TuyuBookingApplicationTarget.host.requireSupportedPlatform();
  if (Platform.environment['TUYU_PACKAGED_SMOKE'] == '1') {
    exit(await runPackagedSmoke());
  }
  const endpoint = String.fromEnvironment('TUYU_SERVE_URL');
  runApp(
    TuyuBookingHostApp(dependencies: AppDependencies.production(endpoint)),
  );
}
