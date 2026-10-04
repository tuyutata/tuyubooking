import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/client/client_initialization_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';
import 'package:tuyubooking/shared/localization/locale_policy.dart';

final class TuyuBookingClientApp extends StatefulWidget {
  const TuyuBookingClientApp({super.key});

  @override
  State<TuyuBookingClientApp> createState() => _TuyuBookingClientAppState();
}

final class _TuyuBookingClientAppState extends State<TuyuBookingClientApp> {
  late final AppLifecycleListener _lifecycle;
  CitizenSdk? _citizenSdk;
  Future<void>? _citizenSdkStop;
  bool _citizenSdkStarting = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onDetach: () => unawaited(_stopCitizenSdk()),
    );
    // CitizenSdk belongs to this client device. No host database, native
    // runtime, or upstream process is created by the client application.
    unawaited(_startCitizenSdk());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_stopCitizenSdk());
    super.dispose();
  }

  Future<void> _startCitizenSdk() async {
    if (_citizenSdkStarting || _citizenSdk != null) return;
    setState(() => _citizenSdkStarting = true);
    CitizenSdk? sdk;
    try {
      sdk = await CitizenSdk.open();
      await sdk.start();
      if (!mounted) {
        await sdk.stop();
        await sdk.close();
        return;
      }
      setState(() {
        _citizenSdk = sdk;
        _citizenSdkStarting = false;
      });
    } on Object {
      if (sdk != null) {
        try {
          await sdk.close();
        } on Object {
          // The initialization UI will expose retry after SDK integration.
        }
      }
      if (mounted) setState(() => _citizenSdkStarting = false);
    }
  }

  Future<void> _stopCitizenSdk() => _citizenSdkStop ??= () async {
    final sdk = _citizenSdk;
    _citizenSdk = null;
    if (sdk == null) return;
    try {
      await sdk.stop();
    } finally {
      await sdk.close();
    }
  }();

  @override
  Widget build(BuildContext context) => Provider<CitizenSdk?>.value(
    value: _citizenSdk,
    child: MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      supportedLocales: TuyuLocalePolicy.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: TuyuLocalePolicy.resolve,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffc14f2f),
          primary: const Color(0xffa43d24),
          secondary: const Color(0xff146c72),
          surface: const Color(0xfffffbf2),
        ),
        scaffoldBackgroundColor: const Color(0xfffff7e7),
        fontFamily: 'serif',
        useMaterial3: true,
      ),
      home: ClientInitializationPage(
        sdk: _citizenSdk,
        sdkStarting: _citizenSdkStarting,
        onRetrySdk: _startCitizenSdk,
      ),
    ),
  );
}
