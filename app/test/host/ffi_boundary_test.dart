import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/authentication/auth_model.dart';

import '../test_support.dart';

void main() {
  test('missing native library fails asynchronously without poisoning the queue', () async {
    // flutter_tester 未打包商家原生库；只查询合同，不启动本地服务。
    const gateway = FfiNativeGateway();
    final first = gateway.contract();
    await expectLater(first, throwsUnsupportedError);
    await expectLater(gateway.contract(), throwsUnsupportedError);
  });

  test('administrator QR response contains public evidence only', () {
    const response = QrLoginResponse(
      protocol: 'TUYU',
      version: 1,
      kind: 2,
      requestId: 'challenge-test',
      expiresAtMilliseconds: 2000000000000,
      publicKey:
          '0x7c0f469d3bd340bae718203fa30ca071a5e37c751e891dbded837b213d45d91d',
      signature:
          '0x2abc1f9292ea9e9cd023fa66be59e59ada5ebbe93e483e97d7733a6a8b2c1023cb193142b795704b355f88c493fa521fdb5bea6198a75aca3f3fa17d777e6980',
    );
    final encoded = jsonEncode(response.toJson()).toLowerCase();
    expect(encoded, isNot(contains('private_key')));
    expect(encoded, isNot(contains('mnemonic')));
    expect(encoded, isNot(contains('seed_phrase')));
    expect(encoded, isNot(contains('server_session_token')));
    expect(encoded, isNot(contains('tuyu_number')));
  });

  test('administrator QR response rejects unknown identity fields', () {
    final raw = jsonEncode({
      'p': 'TUYU',
      'v': 1,
      'k': 2,
      'i': 'challenge-test',
      'e': 2000000000,
      'b': {
        'u': 'ERERERERERERERERERERERERERERERERERERERERERE',
        's': 'signature',
      },
      'private_key': 'forbidden',
    });
    expect(() => QrLoginResponse.fromQrPayload(raw), throwsFormatException);
  });

  test('administrator QR response rejects noncanonical public evidence', () {
    final wrongVersion = jsonEncode({
      'p': 'TUYU',
      'v': 2,
      'k': 2,
      'i': 'tyc_00112233445566778899aabbccddeeff',
      'e': 2000000000000,
      'b': {
        'u':
            '0x7c0f469d3bd340bae718203fa30ca071a5e37c751e891dbded837b213d45d91d',
        's':
            '0x2abc1f9292ea9e9cd023fa66be59e59ada5ebbe93e483e97d7733a6a8b2c1023cb193142b795704b355f88c493fa521fdb5bea6198a75aca3f3fa17d777e6980',
      },
    });
    expect(
      () => QrLoginResponse.fromQrPayload(wrongVersion),
      throwsFormatException,
    );

    final uppercaseKey = jsonEncode({
      'p': 'TUYU',
      'v': 1,
      'k': 2,
      'i': 'tyc_00112233445566778899aabbccddeeff',
      'e': 2000000000000,
      'b': {
        'u':
            '0x7C0F469D3BD340BAE718203FA30CA071A5E37C751E891DBDED837B213D45D91D',
        's':
            '0x2abc1f9292ea9e9cd023fa66be59e59ada5ebbe93e483e97d7733a6a8b2c1023cb193142b795704b355f88c493fa521fdb5bea6198a75aca3f3fa17d777e6980',
      },
    });
    expect(
      () => QrLoginResponse.fromQrPayload(uppercaseKey),
      throwsFormatException,
    );
  });

  test('Flutter accepts only a response for its current challenge', () async {
    final dependencies = testDependencies();
    await dependencies.auth.loadAdministratorState();
    await dependencies.auth.createLoginChallenge();
    final challenge = dependencies.auth.challenge!;
    final response =
        jsonDecode(fakeLoginResponse(challenge)) as Map<String, dynamic>;
    response['i'] = 'tyc_ffffffffffffffffffffffffffffffff';

    await dependencies.auth.completeLoginQr(jsonEncode(response));
    expect(dependencies.auth.status, AuthStatus.failed);
    expect(dependencies.auth.nativeSession, isNull);
  });
}
