import 'package:flutter_test/flutter_test.dart';

import 'source_paths.dart';

void main() {
  test('TuyuBooking uses CitizenSdk without a product-side SDK wrapper', () {
    final host = bookingAppFile('lib/host/host_app.dart').readAsStringSync();
    final client = bookingAppFile('lib/client/client_app.dart').readAsStringSync();

    expect(bookingAppFile('lib/shared/citizen_sdk_runtime.dart').existsSync(), isFalse);
    for (final source in <String>[host, client]) {
      expect(source, contains("package:citizen_sdk/citizen_sdk.dart"));
      expect(source, contains('CitizenSdk.open()'));
      expect(source, isNot(contains('CitizenSdkClient')));
      expect(source, isNot(contains('CitizenSdkRuntime')));
      expect(source, isNot(contains('readOnly')));
      expect(source, isNot(contains('watchOnly')));
    }
  });
}
