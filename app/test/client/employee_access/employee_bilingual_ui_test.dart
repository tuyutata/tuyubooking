import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';

void main() {
  const copy = BilingualCopy(zh: '员工登录', en: 'Employee sign in');

  testWidgets('Chinese device promotes Chinese and assists in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: [Locale('zh'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: BilingualText(copy)),
      ),
    );
    final chinese = tester.widget<Text>(find.text('员工登录'));
    final english = tester.widget<Text>(find.text('Employee sign in'));
    expect(chinese.style!.fontSize!, greaterThan(english.style!.fontSize!));
  });

  testWidgets('English device promotes English and assists in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('zh'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: BilingualText(copy)),
      ),
    );
    final chinese = tester.widget<Text>(find.text('员工登录'));
    final english = tester.widget<Text>(find.text('Employee sign in'));
    expect(english.style!.fontSize!, greaterThan(chinese.style!.fontSize!));
  });
}
