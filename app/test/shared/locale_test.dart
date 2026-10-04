import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/host_app.dart';
import 'package:tuyubooking/shared/localization/locale_policy.dart';

import '../test_support.dart';

void main() {
  test('supports Chinese and English only', () {
    expect(TuyuLocalePolicy.supportedLocales, const [
      Locale('zh'),
      Locale('en'),
    ]);
  });

  test('defaults unsupported and unavailable locales to Chinese', () {
    const supported = TuyuLocalePolicy.supportedLocales;
    expect(
      TuyuLocalePolicy.resolve(const Locale('zh', 'TW'), supported),
      const Locale('zh'),
    );
    expect(
      TuyuLocalePolicy.resolve(const Locale('en', 'US'), supported),
      const Locale('en'),
    );
    expect(
      TuyuLocalePolicy.resolve(const Locale('fr'), supported),
      const Locale('zh'),
    );
    expect(TuyuLocalePolicy.resolve(null, supported), const Locale('zh'));
  });

  testWidgets('follows Chinese and English system locales', (tester) async {
    final chinese = testDependencies();
    await chinese.runtime.start();
    tester.binding.platformDispatcher.localesTestValue = const [Locale('zh')];
    await tester.pumpWidget(
      TuyuBookingHostApp(
        key: const ValueKey('chinese-app'),
        dependencies: chinese,
        autoStartRuntime: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('管理员登录'), findsOneWidget);

    final english = testDependencies();
    await english.runtime.start();
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      TuyuBookingHostApp(
        key: const ValueKey('english-app'),
        dependencies: english,
        autoStartRuntime: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrator sign-in'), findsOneWidget);
    tester.binding.platformDispatcher.clearLocalesTestValue();
  });
}
