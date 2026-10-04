import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/business_mode_selection.dart';
import 'package:tuyubooking/client/business_mode.dart';
import 'package:tuyubooking/client/business_mode_selection_page.dart';
import 'package:tuyubooking/shared/localization/locale_policy.dart';

BusinessModeSelection _testSelection(String name) => BusinessModeSelection(
  // Widget tests never persist; real file I/O is covered by the unit test.
  storageFile: File(
    '${Directory.systemTemp.path}/unused-business-mode-$name.json',
  ),
);

Widget _testApp(Locale locale, BusinessModeSelection selection) => MaterialApp(
  locale: locale,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: TuyuLocalePolicy.supportedLocales,
  home: BusinessModeSelectionPage(selection: selection, loadOnStart: false),
);

void main() {
  test('business-mode selection persists multiple modes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tuyubooking-business-modes-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final storage = File('${directory.path}/selection.json');
    final selection = BusinessModeSelection(storageFile: storage)
      ..toggle(BusinessMode.hotel)
      ..toggle(BusinessMode.restaurant);

    await selection.save();
    final restored = BusinessModeSelection(storageFile: storage);
    await restored.load();

    expect(
      restored.selected,
      equals(<BusinessMode>{BusinessMode.hotel, BusinessMode.restaurant}),
    );
  });

  testWidgets('Chinese is primary while English remains visible', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const Locale('zh'), _testSelection('zh')));

    expect(find.text('选择经营模式'), findsOneWidget);
    expect(find.text('Choose business modes'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('选择经营模式')).dy,
      lessThan(tester.getTopLeft(find.text('Choose business modes')).dy),
    );
  });

  testWidgets('English is primary while Chinese remains visible', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const Locale('en'), _testSelection('en')));

    expect(find.text('Choose business modes'), findsOneWidget);
    expect(find.text('选择经营模式'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Choose business modes')).dy,
      lessThan(tester.getTopLeft(find.text('选择经营模式')).dy),
    );
  });

  testWidgets('multiple business modes enable continuation', (tester) async {
    final selection = _testSelection('interaction');
    await tester.pumpWidget(_testApp(const Locale('zh'), selection));

    await tester.tap(find.byKey(const ValueKey('business-mode-hotel')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('business-mode-ticket')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      selection.selected,
      equals(<BusinessMode>{BusinessMode.hotel, BusinessMode.ticket}),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('save-business-modes')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
