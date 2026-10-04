import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/host_app.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';

import '../test_support.dart';

void main() {
  testWidgets('one verified Tuyu login exposes all four subsystems', (
    tester,
  ) async {
    final dependencies = testDependencies();
    await dependencies.runtime.start();
    await authenticate(dependencies);
    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('module-hotel')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-restaurant')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-tour')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-ticket')), findsOneWidget);
    expect(find.text('Install'), findsNothing);
    expect(find.text('Select modules'), findsNothing);
    expect(find.text('安装模块'), findsNothing);
    expect(find.text('选择模块'), findsNothing);
  });

  testWidgets('a failed subsystem restarts without changing sibling modules', (
    tester,
  ) async {
    final native = FakeNativeGateway(
      snapshot: const NativeRuntimeSnapshot(
        ready: true,
        schemas: [
          'tuyu_core',
          'module_kamra',
          'module_ury',
          'module_voyant',
          'module_hi_events',
        ],
        businessReady: false,
        moduleConfigurationComplete: true,
        enabledModules: [
          MerchantSubsystem.hotel,
          MerchantSubsystem.restaurant,
          MerchantSubsystem.tour,
          MerchantSubsystem.ticket,
        ],
        httpsOrigin: 'https://merchant.local:58443',
        modules: [
          NativeModuleRuntimeState(
            id: 'hotel',
            status: NativeModuleRuntimeStatus.ready,
            schema: 'module_kamra',
            httpsOrigin: 'https://merchant.local:58443',
          ),
          NativeModuleRuntimeState(
            id: 'restaurant',
            status: NativeModuleRuntimeStatus.ready,
            schema: 'module_ury',
            httpsOrigin: 'https://merchant.local:58450',
          ),
          NativeModuleRuntimeState(
            id: 'tour',
            status: NativeModuleRuntimeStatus.ready,
            schema: 'module_voyant',
            httpsOrigin: 'https://merchant.local:58444',
          ),
          NativeModuleRuntimeState(
            id: 'ticket',
            status: NativeModuleRuntimeStatus.failed,
            schema: 'module_hi_events',
            error: 'test failure',
          ),
        ],
      ),
    );
    final dependencies = testDependencies(nativeGateway: native);
    await dependencies.runtime.start();
    await authenticate(dependencies);
    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('restart-ticket')), findsOneWidget);
    expect(find.byKey(const ValueKey('restart-hotel')), findsNothing);
    final restartTicket = find.byKey(const ValueKey('restart-ticket'));
    await tester.ensureVisible(restartTicket);
    await tester.pumpAndSettle();
    await tester.tap(restartTicket);
    await tester.pumpAndSettle();

    expect(native.restartedModules, [MerchantSubsystem.ticket]);
    expect(find.byKey(const ValueKey('restart-ticket')), findsNothing);
    expect(find.byKey(const ValueKey('module-hotel')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-restaurant')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-tour')), findsOneWidget);
  });

  testWidgets('disposing the unified app stops the native runtime', (
    tester,
  ) async {
    final native = FakeNativeGateway();
    final dependencies = testDependencies(nativeGateway: native);
    await dependencies.runtime.start();
    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(native.stopCount, 1);
  });

  testWidgets('desktop exit waits for the unified runtime to stop', (
    tester,
  ) async {
    final native = FakeNativeGateway();
    final dependencies = testDependencies(nativeGateway: native);
    await dependencies.runtime.start();
    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );

    final response = await tester.binding.handleRequestAppExit();

    expect(response, AppExitResponse.exit);
    expect(native.stopCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(native.stopCount, 1);
  });
}
