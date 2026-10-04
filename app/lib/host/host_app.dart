import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/host/startup_page.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';
import 'package:tuyubooking/host/administrators/administrator_controller.dart';
import 'package:tuyubooking/host/administrators/administrator_initialization_page.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';
import 'package:tuyubooking/host/authentication/auth_model.dart';
import 'package:tuyubooking/host/authentication/login_page.dart';
import 'package:tuyubooking/host/business_module_selection_page.dart';
import 'package:tuyubooking/host/workspace/merchant_home_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';
import 'package:tuyubooking/shared/localization/locale_policy.dart';

final class AppDependencies {
  const AppDependencies({
    required this.runtime,
    required this.auth,
    required this.administrators,
    required this.qrScanner,
  });
  final RuntimeController runtime;
  final AuthController auth;
  final AdministratorController administrators;
  final QrScanner qrScanner;

  factory AppDependencies.production(String _) {
    final native = const FfiNativeGateway();
    final auth = AuthController(nativeGateway: native);
    return AppDependencies(
      runtime: RuntimeController(
        gateway: native,
        configuration: DesktopRuntimeConfiguration(),
      ),
      auth: auth,
      administrators: AdministratorController(
        nativeGateway: native,
        auth: auth,
      ),
      qrScanner: const DesktopQrScanner(),
    );
  }
}

final class TuyuBookingHostApp extends StatefulWidget {
  const TuyuBookingHostApp({
    required this.dependencies,
    this.autoStartRuntime = true,
    super.key,
  });
  final AppDependencies dependencies;
  final bool autoStartRuntime;

  @override
  State<TuyuBookingHostApp> createState() => _TuyuBookingHostAppState();
}

final class _TuyuBookingHostAppState extends State<TuyuBookingHostApp> {
  late final AppLifecycleListener _lifecycle;
  CitizenSdk? _citizenSdk;
  Future<void>? _citizenSdkStop;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: _stopBeforeExit,
      onDetach: () => unawaited(_stopServices()),
    );
    unawaited(_startCitizenSdk());
    // Only the host entrypoint owns PostgreSQL and upstream process lifecycle.
    // Runtime startup restores the persisted module set and starts only the
    // subsystems enabled by this merchant.
    if (widget.autoStartRuntime) widget.dependencies.runtime.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_stopServices());
    super.dispose();
  }

  /// Desktop termination is cancelable while this Future runs. Awaiting the
  /// native stop prevents PostgreSQL and module supervisors from outliving the
  /// macOS/Windows/Linux host process after an ordinary Quit action.
  Future<AppExitResponse> _stopBeforeExit() async {
    await _stopServices();
    return AppExitResponse.exit;
  }

  Future<void> _stopServices() => Future.wait<void>([
    widget.dependencies.runtime.stop(),
    _stopCitizenSdk(),
  ]);

  Future<void> _startCitizenSdk() async {
    CitizenSdk? sdk;
    try {
      sdk = await CitizenSdk.open();
      await sdk.start();
      if (!mounted) {
        await sdk.stop();
        await sdk.close();
        return;
      }
      setState(() => _citizenSdk = sdk);
    } on Object {
      if (sdk != null) {
        try {
          await sdk.close();
        } on Object {
          // The primary SDK startup failure remains non-fatal to local trade.
        }
      }
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
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: widget.dependencies.runtime),
      ChangeNotifierProvider.value(value: widget.dependencies.auth),
      ChangeNotifierProvider.value(value: widget.dependencies.administrators),
      Provider<CitizenSdk?>.value(value: _citizenSdk),
      Provider<QrScanner>.value(value: widget.dependencies.qrScanner),
    ],
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
          seedColor: const Color(0xffae432a),
          primary: const Color(0xffae432a),
          secondary: const Color(0xff2f7c80),
          surface: const Color(0xfffff7ee),
        ),
        scaffoldBackgroundColor: const Color(0xfffff7ee),
        fontFamilyFallback: const [
          'PingFang SC',
          'Microsoft YaHei UI',
          'Noto Sans CJK SC',
          'Segoe UI Variable',
        ],
        cardTheme: CardThemeData(
          color: const Color(0xfffffbf7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfffffdf9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x33905f4f)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x33905f4f)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const _RootGate(),
    ),
  );
}

final class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

final class _RootGateState extends State<_RootGate> {
  bool _stateRequestScheduled = false;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<RuntimeController>();
    if (runtime.status != RuntimeStatus.ready &&
        runtime.status != RuntimeStatus.degraded) {
      return const StartupPage();
    }
    final auth = context.watch<AuthController>();
    if (!auth.hasCheckedState && !_stateRequestScheduled) {
      _stateRequestScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => auth.loadAdministratorState(),
      );
    }
    if (auth.administratorState?.initialized == false) {
      return const AdministratorInitializationPage();
    }
    return switch (auth.status) {
      AuthStatus.unchecked || AuthStatus.checking => const StartupPage(),
      AuthStatus.authenticated when !runtime.moduleConfigurationComplete =>
        const BusinessModuleSelectionPage(initialization: true),
      AuthStatus.authenticated => const MerchantHomePage(),
      _ => const LoginPage(),
    };
  }
}
