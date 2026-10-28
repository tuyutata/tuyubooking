import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/account_codec.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/platform/citizen_sdk_platform.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/client_initialization_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

import '../shared/source_paths.dart';

void main() {
  walletEntryWidgetTests();
  test('钱包实现只消费SDK公开操作和状态，不保留旧接口或秘密持久化', () {
    final source = bookingAppFile('lib/client/client_initialization_page.dart')
        .readAsStringSync();
    expect(source, contains('sdk.wallet.getState().result'));
    expect(source, contains('sdk.wallet.prepareCreation('));
    expect(source, contains('_prepared!.commit()'));
    expect(source, isNot(contains('wallet.getProfile(')));
    expect(source, isNot(contains('wallet.create(')));
    for (final forbidden in [
      'writeAsString',
      'SharedPreferences',
      'privateKey',
      'bytesToHex',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
    expect(
      source.indexOf('if (!walletReady(state))'),
      lessThan(source.indexOf('BusinessModeSelection.createDefault()')),
    );
  });
}

// 仅模拟公开SDK通道；合成文本不是助记词，不冒充Core密码学或设备认证。
final class _WalletEntryPlatform implements CitizenSdkPlatform {
  final controller = StreamController<Object?>.broadcast();
  final calls = <String>[];
  final cancelled = <String>{};
  CitizenSdkErrorCode? failure;
  Completer<void>? pending;
  Completer<void>? backupPending;
  int releaseFailures = 0;
  bool committed = true,
      failRead = false,
      passwordValid = true,
      mnemonicValid = true;
  bool recovering = false, cleanupPending = false;
  bool cancellable = true;
  Object? profile;
  int sessions = 0,
      commitCalls = 0,
      releaseCalls = 0,
      reads = 0,
      validations = 0;
  Uint8List? backupRaw;
  Object publicProfile(String origin) {
    final id = '0x${'11' * 32}';
    return [
      0,
      origin,
      '0',
      id,
      id,
      [
        [0, id, citizenSs58FromAccountId(id), 'Fixture account', '0', true],
      ],
      'Fixture wallet',
    ];
  }

  List<Object?> state() {
    final id = '0x${'11' * 32}';
    return [
      '1',
      profile,
      profile == null
          ? <Object?>[]
          : [
              [
                'hot',
                0,
                0,
                id,
                citizenSs58FromAccountId(id),
                'Fixture account',
                '0',
                true,
              ],
            ],
      recovering || cleanupPending
          ? 2
          : profile == null
          ? 0
          : 1,
      cleanupPending,
      profile == null ? null : 0,
      <Object?>[],
    ];
  }

  @override
  Stream<Object?> get events => controller.stream;
  @override
  Future<Object?> invoke(String method, List<Object?> values) async {
    expect(values.first, 2);
    calls.add(method);
    if (method == 'open') {
      return [
        2,
        'wallet-session-${++sessions}',
        0,
        ['created', 1],
      ];
    }
    final header = [2, values[1], values[2]], key = '${values[1]}:${values[2]}';
    CitizenSdkException error(CitizenSdkErrorCode code) => CitizenSdkException(
      code: code,
      message: 'fixture-error-not-for-display',
      method: method,
      sessionId: values[1]! as String,
      requestSequence: values[2]! as int,
    );
    if (method == 'close') {
      return [
        ...header,
        ['disposed'],
      ];
    }
    if (method == 'getWalletState') {
      reads++;
      if (failRead) throw error(CitizenSdkErrorCode.storage);
      return [
        ...header,
        [state()],
      ];
    }
    if (method == 'validateWalletPassword') {
      return [
        ...header,
        [passwordValid ? 0 : 5, null],
      ];
    }
    if (method == 'validateWalletMnemonic') {
      validations++;
      return [
        ...header,
        [mnemonicValid ? 0 : 2, null],
      ];
    }
    if (method == 'cancelOperation') {
      if (!cancellable) {
        return [
          ...header,
          [false],
        ];
      }
      cancelled.add('${values[1]}:${values[3]}');
      if (pending != null && !pending!.isCompleted) pending!.complete();
      return [
        ...header,
        [true],
      ];
    }
    if (method == 'releasePreparedWallet') {
      releaseCalls++;
      if (releaseFailures > 0) {
        releaseFailures--;
        throw error(CitizenSdkErrorCode.busy);
      }
      return [...header, <Object?>[]];
    }
    if (method == 'copyRecoveryPhrase') {
      await backupPending?.future;
      backupRaw = Uint8List.fromList(utf8.encode('synthetic backup only'));
      return [
        ...header,
        [backupRaw],
      ];
    }
    if ([
      'prepareWalletCreation',
      'importWallet',
      'addNextWalletAccount',
      'commitWalletCreation',
    ].contains(method)) {
      await pending?.future;
      if (cancelled.contains(key)) throw error(CitizenSdkErrorCode.cancelled);
      if (failure != null) throw error(failure!);
      if (method == 'prepareWalletCreation') {
        return [
          ...header,
          ['prepared-${values[1]}'],
        ];
      }
      if (method == 'commitWalletCreation') commitCalls++;
      final result = publicProfile(
        method == 'importWallet' ? 'imported' : 'created',
      );
      if (committed) profile = result;
      return [
        ...header,
        [result],
      ];
    }
    throw StateError('Unconfigured SDK fixture method: $method');
  }
}

void walletEntryWidgetTests() {
  late _WalletEntryPlatform platform;
  late CitizenSdk sdk;
  final opened = <CitizenSdk>[];
  late Directory support;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    platform = _WalletEntryPlatform();
    CitizenSdkPlatform.instance = platform;
    sdk = await CitizenSdk.open();
    opened.add(sdk);
    support = await Directory(
      Platform.environment['TUYUBOOKING_TEST_WORK_DIR'] ??
          Directory.systemTemp.path,
    ).createTemp('wallet-profile-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _WalletEntryPaths(support.path);
  });
  tearDown(() async {
    if (platform.pending != null && !platform.pending!.isCompleted) {
      platform.pending!.complete();
    }
    if (platform.backupPending != null &&
        !platform.backupPending!.isCompleted) {
      platform.backupPending!.complete();
    }
    for (final sdk in opened.reversed) {
      await sdk.close();
    }
    opened.clear();
    CitizenSdkPlatform.instance = null;
    PathProviderPlatform.instance = originalPaths;
    await support.delete(recursive: true);
    await platform.controller.close();
  });
  Widget page(String language) => MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: ClientInitializationPage(
      sdk: sdk,
      sdkStarting: false,
      onRetrySdk: () {},
    ),
  );
  // 业务选择使用真实隔离文件；在真实事件循环中等待IO，不推进虚拟时钟假装完成。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.binding.hasScheduledFrame) return;
    }
    fail('钱包界面或隔离业务IO未结束');
  }

  Finder ready() => find.byKey(const ValueKey('save-business-modes'));
  Future<void> openAction(WidgetTester tester, String action) async {
    await tester.ensureVisible(find.byKey(ValueKey(action)));
    await tester.tap(find.byKey(ValueKey(action)));
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester, {bool restore = false}) async {
    if (restore) {
      await tester.enterText(
        find.byKey(const ValueKey('wallet-mnemonic')),
        'synthetic recovery text',
      );
    }
    await tester.ensureVisible(find.byKey(const ValueKey('wallet-submit')));
    await tester.tap(find.byKey(const ValueKey('wallet-submit')));
    await settle(tester);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('wallet-confirm')));
    await tester.pump();
    await submit(tester);
  }

  testWidgets('创建必须备份确认后才真实提交，随后释放准备资源', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    expect(find.byKey(const ValueKey('wallet-backup')), findsOneWidget);
    expect(platform.commitCalls, 0);
    expect(ready(), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('wallet-submit')))
          .onPressed,
      isNull,
    );
    expect(platform.backupRaw, everyElement(0));
    await confirm(tester);
    expect(ready(), findsOneWidget);
    expect(platform.commitCalls, 1);
    expect(platform.releaseCalls, 1);
    expect(
      platform.calls.where((x) => x == 'prepareWalletCreation'),
      hasLength(1),
    );
  });
  testWidgets('导入只使用SDK校验和一次真实操作，回读后放行业务', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'import-wallet');
    await submit(tester, restore: true);
    expect(ready(), findsOneWidget);
    expect(platform.validations, 1);
    expect(platform.calls.where((x) => x == 'importWallet'), hasLength(1));
    expect(
      (await sdk.wallet.getState().result).hotProfile!.origin,
      CitizenWalletOrigin.imported,
    );
  });
  testWidgets('SDK校验失败不提交，输入不进入错误文案', (tester) async {
    platform.mnemonicValid = false;
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'import-wallet');
    await submit(tester, restore: true);
    expect(platform.calls, isNot(contains('importWallet')));
    expect(ready(), findsNothing);
    expect(
      find.text('synthetic recovery text'),
      findsOneWidget,
    ); // 仅用户自己输入框内可见。
    expect(find.textContaining('校验要求'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await settle(tester);
    expect(find.text('synthetic recovery text'), findsNothing);
  });
  testWidgets('附加密码由SDK校验，不合格时不准备钱包', (tester) async {
    platform.passwordValid = false;
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    expect(platform.calls, isNot(contains('prepareWalletCreation')));
    expect(find.textContaining('附加密码不符合'), findsOneWidget);
  });
  testWidgets('备份界面取消只归还资源，不创建或删除钱包', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await settle(tester);
    expect(platform.releaseCalls, 1);
    expect(platform.commitCalls, 0);
    expect(ready(), findsNothing);
    expect(platform.calls, isNot(contains('deleteWallet')));
    expect(find.byKey(const ValueKey('wallet-backup')), findsNothing);
  });
  testWidgets('取消进行中的准备等待真实终态，不放行迟到结果', (tester) async {
    platform.pending = Completer<void>();
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await tester.tap(find.byKey(const ValueKey('wallet-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await settle(tester);
    expect(platform.calls, contains('cancelOperation'));
    expect(platform.commitCalls, 0);
    expect(find.byKey(const ValueKey('wallet-backup')), findsNothing);
    expect(ready(), findsNothing);
  });
  testWidgets('未提交的SDK结果不能绕过真实目录回读', (tester) async {
    platform.committed = false;
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    await confirm(tester);
    expect(platform.commitCalls, 1);
    expect(ready(), findsNothing);
    expect(find.byKey(const ValueKey('create-wallet')), findsOneWidget);
  });
  testWidgets('真实提交后目录读取失败仍不放行业务', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    platform.failRead = true;
    await confirm(tester);
    expect(ready(), findsNothing);
    expect(find.textContaining('fixture-read-error'), findsNothing);
    expect(find.textContaining('fixture-error-not-for-display'), findsNothing);
  });
  for (final code in [
    CitizenSdkErrorCode.cancelled,
    CitizenSdkErrorCode.authenticationCancelled,
  ]) {
    testWidgets('SDK取消不显示真实失败：${code.name}', (tester) async {
      platform.failure = code;
      await tester.pumpWidget(page('zh'));
      await settle(tester);
      await openAction(tester, 'create-wallet');
      await submit(tester);
      expect(find.byKey(const ValueKey('wallet-submit')), findsNothing);
      expect(find.textContaining('钱包操作失败'), findsNothing);
      expect(ready(), findsNothing);
    });
  }
  testWidgets('真实失败可重试且不回显SDK原始异常', (tester) async {
    platform.failure = CitizenSdkErrorCode.storage;
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    expect(find.textContaining('钱包操作失败'), findsOneWidget);
    expect(find.textContaining('fixture-error-not-for-display'), findsNothing);
    platform.failure = null;
    await submit(tester);
    await confirm(tester);
    expect(ready(), findsOneWidget);
  });
  testWidgets('重复点击只出现一个弹窗并提交一次', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-wallet')),
    );
    button.onPressed!();
    button.onPressed!();
    await settle(tester);
    expect(find.byKey(const ValueKey('wallet-submit')), findsOneWidget);
    await submit(tester);
    await confirm(tester);
    expect(platform.commitCalls, 1);
  });
  testWidgets('页面销毁期间真实操作被取消，禁止迟到导航', (tester) async {
    platform.pending = Completer<void>();
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await tester.tap(find.byKey(const ValueKey('wallet-submit')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    expect(platform.commitCalls, 0);
    expect(platform.calls, contains('cancelOperation'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('SDK替换关闭旧备份资源，不推进新实例', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    sdk = await CitizenSdk.open();
    opened.add(sdk);
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    expect(platform.releaseCalls, 1);
    expect(platform.commitCalls, 0);
    expect(find.byKey(const ValueKey('wallet-backup')), findsNothing);
    expect(ready(), findsNothing);
  });
  testWidgets('现有真实钱包无需重复创建', (tester) async {
    platform.profile = platform.publicProfile('created');
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    expect(ready(), findsOneWidget);
    expect(platform.calls, isNot(contains('prepareWalletCreation')));
  });
  for (final pending in ['recovering', 'cleanup']) {
    testWidgets('SDK恢复或清理状态不能冒充空钱包：$pending', (tester) async {
      platform.recovering = pending == 'recovering';
      platform.cleanupPending = pending == 'cleanup';
      await tester.pumpWidget(page('zh'));
      await settle(tester);
      expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
      expect(ready(), findsNothing);
    });
  }

  testWidgets('备份复制在途时取消等待资源交付并释放，不提前关闭', (tester) async {
    platform.backupPending = Completer<void>();
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await tester.tap(find.byKey(const ValueKey('wallet-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wallet-cancel')), findsOneWidget);
    expect(platform.releaseCalls, 0);
    platform.backupPending!.complete();
    await settle(tester);
    expect(platform.releaseCalls, 1);
    expect(platform.commitCalls, 0);
    expect(find.byKey(const ValueKey('wallet-backup')), findsNothing);
  });
  testWidgets('准备资源归还失败保留所有权，重试归还后才关闭', (tester) async {
    platform.releaseFailures = 1;
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await settle(tester);
    expect(platform.releaseCalls, 1);
    expect(find.byKey(const ValueKey('wallet-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await settle(tester);
    expect(platform.releaseCalls, 2);
    expect(platform.commitCalls, 0);
    expect(find.byKey(const ValueKey('wallet-cancel')), findsNothing);
  });

  testWidgets('取消未被SDK接纳时等待真实终态，显式回读才进入业务', (tester) async {
    await tester.pumpWidget(page('zh'));
    await settle(tester);
    await openAction(tester, 'create-wallet');
    await submit(tester);
    await tester.tap(find.byKey(const ValueKey('wallet-confirm')));
    await tester.pump();
    platform.pending = Completer<void>();
    platform.cancellable = false;
    await tester.tap(find.byKey(const ValueKey('wallet-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wallet-cancel')), findsOneWidget);
    platform.pending!.complete();
    await settle(tester);
    expect(platform.commitCalls, 1);
    expect(ready(), findsNothing);
    await tester.tap(find.byKey(const ValueKey('retry-wallet-check')));
    await settle(tester);
    expect(ready(), findsOneWidget);
    expect(platform.commitCalls, 1);
  });

  testWidgets('凭据只临时交付，不发起钱包变更或保存输入', (tester) async {
    final cancelled = Completer<void>();
    Future<Uint8List?>? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                result = requestWalletCredential(
                  context,
                  CitizenCredentialChallenge(
                    hostOperationId: BigInt.one,
                    keyPurpose: 'fixture',
                    cancelled: cancelled.future,
                  ),
                );
              },
              child: const Text('fixture-credential'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('fixture-credential'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wallet-credential')),
      'fixture-only',
    );
    await tester.tap(find.text('继续'));
    await settle(tester);
    final bytes = await result!;
    expect(utf8.decode(bytes!), 'fixture-only');
    bytes.fillRange(0, bytes.length, 0);
    expect(find.byKey(const ValueKey('wallet-credential')), findsNothing);
    expect(platform.calls, isNot(contains('prepareWalletCreation')));
    cancelled.complete();
    await tester.pump();
  });
  testWidgets('SDK撤销凭据挑战时关闭原弹窗并返回取消', (tester) async {
    final cancelled = Completer<void>();
    Future<Uint8List?>? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                result = requestWalletCredential(
                  context,
                  CitizenCredentialChallenge(
                    hostOperationId: BigInt.one,
                    keyPurpose: 'fixture',
                    cancelled: cancelled.future,
                  ),
                );
              },
              child: const Text('fixture-credential'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('fixture-credential'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wallet-credential')),
      'fixture-only',
    );
    cancelled.complete();
    await settle(tester);
    expect(await result!, isNull);
    expect(find.byKey(const ValueKey('wallet-credential')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['zh', 'en']) {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      testWidgets('双语首屏及钱包输入适应手机：$language $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(page(language));
        await settle(tester);
        expect(find.byType(TextField), findsNothing);
        await openAction(tester, 'import-wallet');
        expect(find.byKey(const ValueKey('wallet-mnemonic')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('wallet-cancel')));
        await tester.tap(find.byKey(const ValueKey('wallet-cancel')));
        await settle(tester);
      });
    }
  }
}

final class _WalletEntryPaths extends PathProviderPlatform {
  _WalletEntryPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
