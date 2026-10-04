import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'dart:io';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/src/platform/citizen_sdk_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tuyubooking/client/client_initialization_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  walletEntryWidgetTests();
  final source = bookingAppFile('lib/client/client_initialization_page.dart').readAsStringSync();
  final app = bookingAppFile('lib/client/client_app.dart').readAsStringSync();

  test('client initialization uses CitizenSdk wallet APIs directly', () {
    expect(source, contains('CitizenSdk? sdk'));
    expect(source, contains('sdk.wallet.getProfile()'));
    expect(source, contains('sdk!.wallet.create()'));
    expect(source, contains('sdk!.wallet.importWallet()'));
    expect(source, isNot(contains('CitizenSdkClient')));
    expect(source, isNot(contains('CitizenSdkRuntime')));
  });

  test('wallet and business modes precede LAN discovery', () {
    expect(
      source.indexOf('sdk.wallet.getProfile()'),
      lessThan(source.indexOf('BusinessModeSelection.createDefault()')),
    );
    expect(source, contains('_ClientInitializationStatus.choosingModes'));
    expect(source, contains('EmployeeDiscoveryPage'));
    expect(app, contains('ClientInitializationPage'));
    expect(app, isNot(contains('home: const EmployeeDiscoveryPage()')));
  });

  test('TuyuBooking never receives wallet secrets', () {
    expect(source, isNot(contains('mnemonic')));
    expect(source, isNot(contains('privateKey')));
    expect(source, isNot(contains('walletPassword')));
    expect(source, isNot(contains('seedPhrase')));
  });

  test('取消安全流程返回入口，真实失败保留重试且不显示原始异常', () {
    expect(source, contains('CitizenSdkErrorCode.cancelled'));
    expect(source, contains('CitizenSdkErrorCode.authenticationCancelled'));
    expect(source, contains('? _ClientInitializationStatus.walletRequired'));
    expect(source, contains(': _ClientInitializationStatus.failed'));
    expect(source, isNot(contains('error.toString()')));
    expect(source, contains("ValueKey('retry-wallet-check')"));
  });

  test('旧SDK结果及重复点击不能推进新页面', () {
    expect(source, contains('if (_walletOperationRunning || sdk == null) return'));
    expect(source, contains('check != _walletCheck'));
    expect(source, contains('!identical(sdk, widget.sdk)'));
    expect(source.indexOf('if (wallet == null)'),
      lessThan(source.indexOf('BusinessModeSelection.createDefault()')));
  });

  test('入口使用正式品牌和可滚动布局，不新增秘密输入框', () {
    expect(source, contains("Image.asset('tuyu_logo.png'"));
    expect(source, contains('SingleChildScrollView'));
    expect(source, contains('_copy(_zh.appTitle, _en.appTitle)'));
    expect(source, isNot(contains('TextField(')));
    expect(source, isNot(contains('TextFormField(')));
  });
}

// 仅替换 SDK 测试传输；实际页面与 CitizenSdk 公开门面照常执行。
final class _WalletEntryPlatform implements CitizenSdkPlatform {
  final controller = StreamController<Object?>.broadcast();
  CitizenSdkErrorCode error = CitizenSdkErrorCode.cancelled;
  Completer<void>? pending;
  int calls = 0;
  int sessions = 0;
  bool succeed = false;
  bool commit = true;
  bool failRead = false;
  Object? profile;
  Object publicProfile(String origin) {
    final id = '0x${List.filled(64, '1').join()}';
    return [0, origin, '0', id, id,
      [[0, id, citizenSs58FromAccountId(id), 'Test account', '0', true]]];
  }
  @override
  Stream<Object?> get events => controller.stream;
  @override
  Future<Object?> invoke(String method, List<Object?> arguments) async {
    if (method == 'open') return [1, 'wallet-entry-${++sessions}', 0, ['created', 1]];
    final header = [1, arguments[1], arguments[2]];
    if (method == 'close') return [...header, ['disposed']];
    if (method == 'getWalletProfile') {
      if (failRead) {
        throw CitizenSdkException(code: CitizenSdkErrorCode.storage,
          message: 'fixture-read-error', sessionId: arguments[1]! as String,
          requestSequence: arguments[2]! as int);
      }
      return [...header, [profile]];
    }
    if (method == 'createWallet' || method == 'importWallet') {
      calls++;
      await pending?.future;
      if (succeed) {
        final result = publicProfile(method == 'importWallet' ? 'imported' : 'created');
        if (commit) profile = result;
        return [...header, [result]];
      }
      // SDK 要求错误精确关联当前请求，测试也遵守同一传输合同。
      throw CitizenSdkException(code: error, message: 'fixture-error-not-for-display',
        sessionId: arguments[1]! as String, requestSequence: arguments[2]! as int);
    }
    throw StateError('Unexpected SDK test method: $method');
  }
}

void walletEntryWidgetTests() {
  late _WalletEntryPlatform platform;
  late CitizenSdk sdk;
  int walletReady = 0;
  int retries = 0;
  late Directory support;
  late PathProviderPlatform originalPaths;
  
  setUp(() async {
    walletReady = 0;
    retries = 0;
    final work = Platform.environment['TUYUBOOKING_TEST_WORK_DIR'] ??
        Directory.systemTemp.path;
    support = await Directory(work).createTemp('wallet-profile-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _WalletEntryPaths(support.path);
    platform = _WalletEntryPlatform();
    CitizenSdkPlatform.instance = platform;
    sdk = await CitizenSdk.open();
    
  });
  tearDown(() async {
    
    await sdk.close();
    PathProviderPlatform.instance = originalPaths;
    await support.delete(recursive: true);
    CitizenSdkPlatform.instance = null;
    await platform.controller.close();
  });
  Widget page(String language, {bool starting = false, bool unavailable = false}) => MaterialApp(
    locale: Locale(language), supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ClientInitializationPage(sdk: unavailable ? null : sdk, sdkStarting: starting, onRetrySdk: () { retries++; }),
  );

  // 生产页面真实处理公开资料；仅磁盘位置和SDK传输由测试隔离。
  Future<void> waitForReady(WidgetTester tester) async {
    for (var i = 0; i < 100 && find.byKey(const ValueKey('save-business-modes')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('save-business-modes')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }
  for(final operation in ['create-wallet', 'import-wallet']) {
    testWidgets('wallet entry success $operation', (tester) async {
      platform.succeed = true;
      await tester.pumpWidget(page('zh'));
      await tester.pumpAndSettle();
      final action = find.byKey(ValueKey(operation));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await waitForReady(tester);
      expect(platform.calls, 1);
      expect((await sdk.wallet.getProfile())!.origin,
        operation == 'create-wallet' ? CitizenWalletOrigin.created : CitizenWalletOrigin.imported);
      
      expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('wallet entry existing committed profile skips setup', (tester) async {
    platform.profile = platform.publicProfile('created');
    
    await tester.pumpWidget(page('zh'));
    await waitForReady(tester);
    expect(platform.calls, 0);
    expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry uncommitted operation cannot enter business', (tester) async {
    platform.succeed = true;
    platform.commit = false;
    await tester.pumpWidget(page('zh'));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('create-wallet'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-business-modes')), findsNothing);
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
    expect(walletReady, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry committed operation with failed read stays closed', (tester) async {
    platform.succeed = true;
    await tester.pumpWidget(page('zh'));
    await tester.pumpAndSettle();
    platform.failRead = true;
    final action = find.byKey(const ValueKey('create-wallet'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-business-modes')), findsNothing);
    expect(find.text('钱包操作失败，请重试。'), findsOneWidget);
    expect(find.textContaining('fixture-read-error'), findsNothing);
    expect(walletReady, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry SDK starting failure retry and recovery', (tester) async {
    await tester.pumpWidget(page('zh', starting: true, unavailable: true));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
    await tester.pumpWidget(page('zh', unavailable: true));
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('retry-citizen-sdk'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(retries, 1);
    await tester.pumpWidget(page('zh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry disposal during operation ignores late result', (tester) async {
    platform.pending = Completer<void>();
    await tester.pumpWidget(page('zh'));
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(find.byKey(const ValueKey('create-wallet'))).onPressed!();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    platform.pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final language in ['zh', 'en']) {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      testWidgets('wallet entry $language $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(page(language));
        await tester.pumpAndSettle();
        expect(find.text('途遇商家端'), findsOneWidget);
        expect(find.text('TuyuBooking'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('import-wallet')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final code in [CitizenSdkErrorCode.cancelled, CitizenSdkErrorCode.authenticationCancelled]) {
    testWidgets('wallet entry cancellation ${code.name}', (tester) async {
      platform.error = code;
      await tester.pumpWidget(page('zh'));
      await tester.pumpAndSettle();
      final action = find.byKey(ValueKey(code == CitizenSdkErrorCode.cancelled ? 'create-wallet' : 'import-wallet'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(platform.calls, 1);
      expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
      expect(find.text('钱包操作失败，请重试。'), findsNothing);
      expect(find.textContaining('fixture-error'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('wallet entry failure remains retryable without raw errors', (tester) async {
    platform.error = CitizenSdkErrorCode.storage;
    await tester.pumpWidget(page('zh'));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('create-wallet'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('钱包操作失败，请重试。'), findsOneWidget);
    expect(find.textContaining('fixture-error'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('retry-wallet-check')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry duplicate click uses one SDK operation', (tester) async {
    platform.pending = Completer<void>();
    await tester.pumpWidget(page('en'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('create-wallet')));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(platform.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    platform.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wallet entry ignores late failure from replaced SDK', (tester) async {
    platform.pending = Completer<void>();
    platform.error = CitizenSdkErrorCode.storage;
    await tester.pumpWidget(page('en'));
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(find.byKey(const ValueKey('create-wallet'))).onPressed!();
    await tester.pump();
    final old = sdk;
    sdk = await CitizenSdk.open();
    await tester.pumpWidget(page('en'));
    await tester.pump();
    platform.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
    expect(find.text('The wallet operation failed. Try again.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await old.close();
  });
}

final class _WalletEntryPaths extends PathProviderPlatform {
  _WalletEntryPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
