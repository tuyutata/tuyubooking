import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';

void main() {
  test(
    'machine runtime credentials persist without an interactive store',
    () async {
      final root = await Directory.systemTemp.createTemp('tuyu-secrets-');
      addTearDown(() => root.delete(recursive: true));
      const store = FileRuntimeSecretStore();

      final first = await store.readOrCreate(root);
      final second = await store.readOrCreate(root);

      expect(second.databasePassword, first.databasePassword);
      expect(
        second.hotelAdministratorPassword,
        first.hotelAdministratorPassword,
      );
      expect(
        second.restaurantAdministratorPassword,
        first.restaurantAdministratorPassword,
      );
      expect(
        File('${root.path}/runtime/internal-secrets.json').existsSync(),
        isTrue,
      );
    },
  );
}
