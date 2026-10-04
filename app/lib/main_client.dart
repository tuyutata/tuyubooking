import 'package:flutter/widgets.dart';
import 'package:tuyubooking/client/client_app.dart';
import 'package:tuyubooking/shared/application_target.dart';

/// Starts the employee client without loading any host runtime component.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TuyuBookingApplicationTarget.client.requireSupportedPlatform();
  runApp(const TuyuBookingClientApp());
}
