import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/host_app.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';

import '../test_support.dart';

void main() {
  RuntimeController controller(_LifecycleGateway gateway) {
    final value = RuntimeController(
      gateway: gateway, configuration: FakeRuntimeConfiguration(),
    );
    addTearDown(value.dispose);
    return value;
  }

  test('core readiness does not wait for a selected module to finish starting', () async {
    final gateway = _LifecycleGateway()
      ..snapshot = const NativeRuntimeSnapshot(
        ready: true, schemas: ['tuyu_core'],
        moduleConfigurationComplete: true,
        enabledModules: [MerchantSubsystem.restaurant],
        modules: [NativeModuleRuntimeState(
          id: 'restaurant', schema: 'module_ury',
          status: NativeModuleRuntimeStatus.starting,
        )],
      );
    final runtime = controller(gateway);
    await runtime.start();
    expect(runtime.status, RuntimeStatus.ready);
    expect(runtime.enabledModules, {MerchantSubsystem.restaurant});
    expect(runtime.moduleState(MerchantSubsystem.hotel), isNull);
  });

  for (final invalid in [
    const NativeRuntimeSnapshot(ready: false, schemas: ['tuyu_core']),
    const NativeRuntimeSnapshot(ready: true, schemas: []),
  ]) {
    test('invalid core snapshot fails startup and an existing runtime', () async {
      final gateway = _LifecycleGateway()..snapshot = invalid;
      final runtime = controller(gateway);
      await runtime.start();
      expect(runtime.status, RuntimeStatus.failed);
      gateway.snapshot = FakeNativeGateway.readySnapshot;
      await runtime.start();
      expect(runtime.status, RuntimeStatus.ready);
      gateway.snapshot = invalid;
      await runtime.refresh();
      expect(runtime.status, RuntimeStatus.failed);
      expect(runtime.httpsOrigin, isNull);
      expect(runtime.error, isA<NativeBridgeException>());
    });
  }

  test('native health error is not reported as usable module degradation', () async {
    final gateway = _LifecycleGateway();
    final runtime = controller(gateway);
    await runtime.start();
    gateway.refresh = () => Future.error(StateError('health query failed'));
    await runtime.refresh();
    expect(runtime.status, RuntimeStatus.failed);
    expect(runtime.moduleOrigin(MerchantSubsystem.restaurant), isNull);
  });

  test('enabled stopped module is degraded and disabled module cannot restart', () async {
    final gateway = _LifecycleGateway()
      ..snapshot = const NativeRuntimeSnapshot(
        ready: true, schemas: ['tuyu_core'],
        enabledModules: [MerchantSubsystem.restaurant],
        modules: [NativeModuleRuntimeState(
          id: 'restaurant', schema: 'module_ury',
          status: NativeModuleRuntimeStatus.stopped,
        )],
      );
    final runtime = controller(gateway);
    await runtime.start();
    expect(runtime.status, RuntimeStatus.degraded);
    await runtime.restartModule(MerchantSubsystem.hotel);
    expect(gateway.restarted, isEmpty);
    await runtime.restartModule(MerchantSubsystem.restaurant);
    expect(gateway.restarted, [MerchantSubsystem.restaurant]);
  });

  test('stop waits for startup and duplicate callers share the shutdown', () async {
    final gateway = _LifecycleGateway();
    final entered = Completer<void>();
    final response = Completer<NativeRuntimeSnapshot>();
    gateway.starting = () { entered.complete(); return response.future; };
    final runtime = controller(gateway);
    final start = runtime.start();
    await entered.future;
    expect(identical(start, runtime.start()), isTrue);
    final stop = runtime.stop();
    expect(identical(stop, runtime.stop()), isTrue);
    expect(gateway.stopCount, 0);
    response.complete(FakeNativeGateway.readySnapshot);
    await Future.wait([start, stop]);
    expect(gateway.stopCount, 1);
    expect(runtime.status, RuntimeStatus.idle);
    expect(runtime.enabledModules, isEmpty);
  });

  test('a refresh finishing during stop cannot resurrect the runtime', () async {
    final gateway = _LifecycleGateway();
    final runtime = controller(gateway);
    await runtime.start();
    final entered = Completer<void>();
    final response = Completer<NativeRuntimeSnapshot>();
    gateway.refresh = () { entered.complete(); return response.future; };
    final refresh = runtime.refresh();
    await entered.future;
    final stop = runtime.stop();
    response.complete(FakeNativeGateway.readySnapshot);
    await Future.wait([refresh, stop]);
    expect(runtime.status, RuntimeStatus.idle);
    expect(runtime.moduleConfigurationComplete, isFalse);
    expect(runtime.httpsOrigin, isNull);
  });

  test('submitted module selection is independent of caller mutations', () async {
    final gateway = _LifecycleGateway();
    final runtime = controller(gateway);
    await runtime.start();
    final selection = {MerchantSubsystem.restaurant};
    final save = runtime.configureBusinessModules(selection);
    selection.add(MerchantSubsystem.hotel);
    await save;
    expect(gateway.configured.single, {MerchantSubsystem.restaurant});
  });

  test('disposing with a pending startup neither notifies nor restores readiness', () async {
    final gateway = _LifecycleGateway();
    final entered = Completer<void>();
    final response = Completer<NativeRuntimeSnapshot>();
    gateway.starting = () { entered.complete(); return response.future; };
    final runtime = RuntimeController(gateway: gateway, configuration: FakeRuntimeConfiguration());
    var notifications = 0;
    runtime.addListener(() => notifications += 1);
    final start = runtime.start();
    await entered.future;
    runtime.dispose();
    final before = notifications;
    response.complete(FakeNativeGateway.readySnapshot);
    await start;
    expect(notifications, before);
    expect(runtime.status, isNot(RuntimeStatus.ready));
    await runtime.stop();
  });

  testWidgets('administrator can keep only the restaurant system enabled', (
    tester,
  ) async {
    final native = FakeNativeGateway();
    final dependencies = testDependencies(nativeGateway: native);
    await dependencies.runtime.start();
    await authenticate(dependencies);
    await tester.pumpWidget(
      TuyuBookingHostApp(dependencies: dependencies, autoStartRuntime: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('business-module-management')));
    await tester.pumpAndSettle();
    final hotel = find.byKey(const ValueKey('select-hotel'));
    await tester.ensureVisible(hotel);
    await tester.tap(hotel);
    await tester.pump();

    final tour = find.byKey(const ValueKey('select-tour'));
    await tester.ensureVisible(tour);
    await tester.tap(tour);
    await tester.pump();

    final ticket = find.byKey(const ValueKey('select-ticket'));
    await tester.ensureVisible(ticket);
    await tester.tap(ticket);
    await tester.pump();
    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    final saveModules = find.byKey(const ValueKey('save-business-modules'));
    await tester.ensureVisible(saveModules);
    await tester.tap(saveModules);
    await tester.pumpAndSettle();

    expect(native.configuredModuleSets.last, {MerchantSubsystem.restaurant});
    expect(find.byKey(const ValueKey('module-restaurant')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-hotel')), findsNothing);
    expect(find.byKey(const ValueKey('module-tour')), findsNothing);
    expect(find.byKey(const ValueKey('module-ticket')), findsNothing);
  });
}

// 仅模拟本机生命周期；未实现的账户调用直接失败，不触碰数据库、磁盘或钱包。
final class _LifecycleGateway implements NativeGateway {
  NativeRuntimeSnapshot snapshot = FakeNativeGateway.readySnapshot;
  Future<NativeRuntimeSnapshot> Function()? starting;
  Future<NativeRuntimeSnapshot> Function()? refresh;
  final configured = <Set<MerchantSubsystem>>[];
  final restarted = <MerchantSubsystem>[];
  int stopCount = 0;

  @override
  Future<NativeRuntimeSnapshot> start(NativeRuntimeRequest request) async =>
      starting == null ? snapshot : starting!();
  @override
  Future<NativeRuntimeSnapshot> runtimeSnapshot() async =>
      refresh == null ? snapshot : refresh!();
  @override
  Future<NativeRuntimeSnapshot> configureBusinessModules(Set<MerchantSubsystem> modules) async {
    configured.add(Set.of(modules));
    return snapshot;
  }
  @override
  Future<NativeRuntimeSnapshot> restartModule(MerchantSubsystem module) async {
    restarted.add(module);
    return snapshot;
  }
  @override
  Future<void> stop() async { stopCount += 1; }
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unexpected account call');
}
