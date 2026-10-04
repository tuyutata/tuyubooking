import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:tuyubooking/client/business_mode_selection.dart';
import 'package:tuyubooking/client/business_mode.dart';
import 'package:tuyubooking/client/host_connection/employee_discovery_page.dart';
import 'package:tuyubooking/client/business_mode_selection_page.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations_en.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations_zh.dart';

enum _ClientInitializationStatus {
  checkingWallet,
  walletRequired,
  choosingModes,
  ready,
  failed,
}

/// Drives the client from its device-local CitizenSdk wallet into the
/// fixed merchant-host connection without handling wallet secrets in Dart.
final class ClientInitializationPage extends StatefulWidget {
  const ClientInitializationPage({
    required this.sdk,
    required this.sdkStarting,
    required this.onRetrySdk,
    super.key,
  });

  final CitizenSdk? sdk;
  final bool sdkStarting;
  final VoidCallback onRetrySdk;

  @override
  State<ClientInitializationPage> createState() =>
      _ClientInitializationPageState();
}

final class _ClientInitializationPageState
    extends State<ClientInitializationPage> {
  final _zh = AppLocalizationsZh();
  final _en = AppLocalizationsEn();
  _ClientInitializationStatus _status =
      _ClientInitializationStatus.checkingWallet;
  BusinessModeSelection? _selection;
  bool _walletOperationRunning = false;
  int _walletCheck = 0;

  BilingualCopy _copy(String zh, String en) => BilingualCopy(zh: zh, en: en);

  @override
  void initState() {
    super.initState();
    if (widget.sdk != null) _checkWalletAndModes();
  }

  @override
  void didUpdateWidget(ClientInitializationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.sdk, oldWidget.sdk)) {
      // SDK 更换后，旧会话的异步结果不能推进新会话页面。
      _walletCheck++;
      _walletOperationRunning = false;
      _status = _ClientInitializationStatus.checkingWallet;
      if (widget.sdk != null) _checkWalletAndModes();
    }
  }

  @override
  void dispose() {
    _selection?.dispose();
    super.dispose();
  }

  Future<void> _checkWalletAndModes() async {
    final sdk = widget.sdk;
    if (sdk == null) return;
    final check = ++_walletCheck;
    setState(() => _status = _ClientInitializationStatus.checkingWallet);
    try {
      final wallet = await sdk.wallet.getProfile();
      if (!mounted || check != _walletCheck) return;
      // 钱包未就绪时只显示入口，不提前读取业务设置或连接商家主机。
      if (wallet == null) {
        setState(() => _status = _ClientInitializationStatus.walletRequired);
        return;
      }
      final selection =
          _selection ?? await BusinessModeSelection.createDefault();
      await selection.load();
      if (!mounted || check != _walletCheck) {
        if (!identical(selection, _selection)) selection.dispose();
        return;
      }
      _selection = selection;
      setState(() {
        _status = selection.selected.isEmpty
            ? _ClientInitializationStatus.choosingModes
            : _ClientInitializationStatus.ready;
      });
    } on Object {
      if (mounted && check == _walletCheck) {
        setState(() => _status = _ClientInitializationStatus.failed);
      }
    }
  }

  Future<void> _createWallet() =>
      _runWalletOperation(() => widget.sdk!.wallet.create());

  Future<void> _importWallet() =>
      _runWalletOperation(() => widget.sdk!.wallet.importWallet());

  Future<void> _runWalletOperation(Future<Object?> Function() operation) async {
    final sdk = widget.sdk;
    if (_walletOperationRunning || sdk == null) return;
    setState(() => _walletOperationRunning = true);
    try {
      await operation();
      if (!mounted || !identical(sdk, widget.sdk)) return;
      await _checkWalletAndModes();
    } on CitizenSdkException catch (error) {
      if (!mounted || !identical(sdk, widget.sdk)) return;
      // 用户主动取消安全界面不是业务失败；不显示 SDK 原始异常内容。
      final cancelled = error.code == CitizenSdkErrorCode.cancelled ||
          error.code == CitizenSdkErrorCode.authenticationCancelled;
      setState(() => _status = cancelled
          ? _ClientInitializationStatus.walletRequired
          : _ClientInitializationStatus.failed);
    } on Object {
      if (mounted && identical(sdk, widget.sdk)) {
        setState(() => _status = _ClientInitializationStatus.failed);
      }
    } finally {
      if (mounted && identical(sdk, widget.sdk)) {
        setState(() => _walletOperationRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sdk == null) {
      return _buildSdkStatus(context);
    }
    if (_status == _ClientInitializationStatus.ready) {
      return EmployeeDiscoveryPage(
        selectedModes: _selection?.selected ?? const <BusinessMode>{},
      );
    }
    if (_status == _ClientInitializationStatus.choosingModes &&
        _selection != null) {
      return BusinessModeSelectionPage(
        selection: _selection!,
        loadOnStart: false,
        onCompleted: (_) async {
          if (mounted) {
            setState(() => _status = _ClientInitializationStatus.ready);
          }
        },
      );
    }
    return _buildWalletStatus(context);
  }

  Widget _buildSdkStatus(BuildContext context) => Scaffold(
    body: _StatusPanel(
      brand: _copy(_zh.appTitle, _en.appTitle),
      title: _copy(_zh.clientSdkTitle, _en.clientSdkTitle),
      subtitle: widget.sdkStarting
          ? _copy(_zh.clientSdkStarting, _en.clientSdkStarting)
          : _copy(_zh.clientSdkUnavailable, _en.clientSdkUnavailable),
      busy: widget.sdkStarting,
      actions: widget.sdkStarting
          ? const []
          : [
              FilledButton(
                key: const ValueKey('retry-citizen-sdk'),
                onPressed: widget.onRetrySdk,
                child: BilingualText(_copy(_zh.clientRetry, _en.clientRetry)),
              ),
            ],
    ),
  );

  Widget _buildWalletStatus(BuildContext context) {
    final checking = _status == _ClientInitializationStatus.checkingWallet;
    final failed = _status == _ClientInitializationStatus.failed;
    return Scaffold(
      body: _StatusPanel(
        brand: _copy(_zh.appTitle, _en.appTitle),
        title: _copy(_zh.clientWalletTitle, _en.clientWalletTitle),
        subtitle: failed
            ? _copy(
                _zh.clientWalletOperationFailed,
                _en.clientWalletOperationFailed,
              )
            : checking
            ? _copy(_zh.clientWalletChecking, _en.clientWalletChecking)
            : _copy(_zh.clientWalletSubtitle, _en.clientWalletSubtitle),
        busy: checking || _walletOperationRunning,
        actions: checking || _walletOperationRunning
            ? const []
            : failed
            ? [
                FilledButton(
                  key: const ValueKey('retry-wallet-check'),
                  onPressed: _checkWalletAndModes,
                  child: BilingualText(_copy(_zh.clientRetry, _en.clientRetry)),
                ),
              ]
            : [
                FilledButton(
                  key: const ValueKey('create-wallet'),
                  onPressed: _createWallet,
                  child: BilingualText(
                    _copy(_zh.clientCreateWallet, _en.clientCreateWallet),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('import-wallet'),
                  onPressed: _importWallet,
                  child: BilingualText(
                    _copy(_zh.clientImportWallet, _en.clientImportWallet),
                  ),
                ),
              ],
      ),
    );
  }
}

final class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.actions,
  });

  final BilingualCopy brand;
  final BilingualCopy title;
  final BilingualCopy subtitle;
  final bool busy;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEAF3EF), Color(0xFFF8FAF8)],
      ),
    ),
    child: SafeArea(child: Center(child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('tuyu_logo.png',
                      width: 96, height: 96, fit: BoxFit.contain,
                      excludeFromSemantics: true),
                  )),
                  const SizedBox(height: 16),
                  BilingualText(brand, textAlign: TextAlign.center,
                    primaryStyle: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  BilingualText(
                    title,
                    textAlign: TextAlign.center,
                    primaryStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  BilingualText(subtitle, textAlign: TextAlign.center),
                  if (busy) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ...actions.expand(
                      (action) => <Widget>[action, const SizedBox(height: 12)],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ))),
  );
}
