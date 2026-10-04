import 'package:flutter_test/flutter_test.dart';

import '../test_support.dart';

void main() {
  test('administrator management never mutates a public key', () async {
    final dependencies = testDependencies();
    await authenticate(dependencies);
    final controller = dependencies.administrators;
    await controller.load();

    await controller.add(
      publicKeyQr:
          r'{"p":"TUYU","v":1,"k":0,"b":{"u":"0x2222222222222222222222222222222222222222222222222222222222222222"}}',
      name: 'Second',
    );
    final added = controller.administrators.last;
    final originalPublicKey = added.publicKey;

    await controller.rename(added.id, 'Renamed');
    expect(controller.administrators.last.name, 'Renamed');
    expect(controller.administrators.last.publicKey, originalPublicKey);

    await controller.setStatus(added.id, false);
    expect(controller.administrators.last.status, 'disabled');
    await controller.delete(added.id);
    expect(controller.administrators, hasLength(1));
  });

  test(
    'disabling the signed-in administrator clears Flutter session state',
    () async {
      final dependencies = testDependencies();
      await authenticate(dependencies);
      final controller = dependencies.administrators;
      await controller.load();

      await controller.setStatus(
        dependencies.auth.nativeSession!.administratorId,
        false,
      );
      expect(dependencies.auth.nativeSession, isNull);
    },
  );
}
