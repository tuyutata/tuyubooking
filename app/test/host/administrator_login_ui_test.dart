import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/host_app.dart';

import '../test_support.dart';

void main() {
  testWidgets('administrator login shares the compact bilingual QR exchange', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final native = FakeNativeGateway(initialized: true);
    final scanner = FakeQrScanner([
      fakeLoginResponse(FakeNativeGateway.qrChallenge),
    ]);
    final dependencies = testDependencies(
      nativeGateway: native,
      scanner: scanner,
    );
    await dependencies.runtime.start();

    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('administrator-login-title')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('login-challenge-qr')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login-signature-camera')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('scan-signature-response')), findsNothing);
    expect(find.text('管理员登录'), findsOneWidget);
    expect(find.text('Administrator sign-in'), findsOneWidget);
    expect(find.text('签名二维码'), findsOneWidget);
    expect(find.text('扫码识别'), findsOneWidget);
    final requestPanel = tester.getSize(
      find.byKey(const ValueKey('signature-request-panel')),
    );
    final responsePanel = tester.getSize(
      find.byKey(const ValueKey('signature-response-panel')),
    );
    expect(requestPanel.width, requestPanel.height);
    expect(responsePanel.width, responsePanel.height);
    expect(requestPanel, responsePanel);
    expect(
      tester.getSize(find.byKey(const ValueKey('login-signature-camera'))),
      const Size.square(224),
    );

    final embeddedScanner = find.byKey(const ValueKey('fake-embedded-qr-scan'));
    await tester.ensureVisible(embeddedScanner);
    await tester.pumpAndSettle();
    await tester.tap(embeddedScanner);
    await tester.pumpAndSettle();

    expect(scanner.scanCount, 1);
    expect(dependencies.auth.nativeSession, isNotNull);
  });
}
