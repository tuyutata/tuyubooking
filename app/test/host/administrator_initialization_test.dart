import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/host_app.dart';

import '../test_support.dart';

void main() {
  testWidgets(
    'first installation initializes an administrator then selects modules',
    (tester) async {
      final native = FakeNativeGateway(initialized: false);
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
        find.byKey(const ValueKey('administrator-initialization-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('administrator-initialization-challenge-qr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('administrator-signature-camera')),
        findsOneWidget,
      );
      expect(find.text('设置管理员'), findsWidgets);
      expect(find.text('Set administrator'), findsWidgets);
      expect(
        find.byKey(const ValueKey('route-atlas-brand-logo')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('route-atlas-step-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-atlas-step-2')), findsOneWidget);
      expect(find.text('用途遇钱包或公民钱包扫码签名'), findsNothing);
      expect(find.text('Sign with Tuyu or Citizen Wallet'), findsNothing);
      expect(find.text('签名二维码'), findsOneWidget);
      expect(find.text('扫码识别'), findsOneWidget);
      expect(find.text('等待签名'), findsOneWidget);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('administrator-signature-camera')),
        ),
        const Size.square(224),
      );
      final requestPanel = tester.getSize(
        find.byKey(const ValueKey('signature-request-panel')),
      );
      final responsePanel = tester.getSize(
        find.byKey(const ValueKey('signature-response-panel')),
      );
      expect(requestPanel.width, requestPanel.height);
      expect(responsePanel.width, responsePanel.height);
      expect(requestPanel, responsePanel);
      expect(native.configuredModuleSets, isEmpty);

      final embeddedScanner = find.byKey(
        const ValueKey('fake-embedded-qr-scan'),
      );
      await tester.ensureVisible(embeddedScanner);
      await tester.tap(embeddedScanner);
      await tester.pumpAndSettle();

      expect(scanner.scanCount, 1);
      expect(native.initializationResponses, hasLength(1));
      expect(dependencies.auth.nativeSession, isNotNull);
      expect(find.byKey(const ValueKey('select-restaurant')), findsOneWidget);
      expect(find.text('选择经营模式'), findsOneWidget);
      expect(find.text('Choose business modes'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-atlas-step-2')), findsOneWidget);

      final restaurant = find.byKey(const ValueKey('select-restaurant'));
      await tester.ensureVisible(restaurant);
      await tester.tap(restaurant);
      await tester.pump();
      final saveModules = find.byKey(const ValueKey('save-business-modules'));
      await tester.ensureVisible(saveModules);
      await tester.tap(saveModules);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('module-restaurant')), findsOneWidget);
      expect(find.byKey(const ValueKey('module-hotel')), findsNothing);
    },
  );
}
