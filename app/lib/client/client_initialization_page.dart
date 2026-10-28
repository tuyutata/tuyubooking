import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';
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
  recovering,
  choosingModes,
  ready,
  failed,
}

/// 钱包事实仅来自SDK；本页只承载临时输入和备份确认，不保存秘密。
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
  Completer<void> _walletGone = Completer<void>();

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
      _walletGone.complete();
      _walletGone = Completer<void>();
      _walletOperationRunning = false;
      _status = _ClientInitializationStatus.checkingWallet;
      if (widget.sdk != null) _checkWalletAndModes();
    }
  }

  @override
  void dispose() {
    if (!_walletGone.isCompleted) _walletGone.complete();
    _selection?.dispose();
    super.dispose();
  }

  Future<void> _checkWalletAndModes() async {
    final sdk = widget.sdk;
    if (sdk == null) return;
    final check = ++_walletCheck;
    setState(() => _status = _ClientInitializationStatus.checkingWallet);
    try {
      final state = await sdk.wallet.getState().result;
      if (!mounted || check != _walletCheck) return;
      // 钱包未就绪时只显示入口，不提前读取业务设置或连接商家主机。
      if (!walletReady(state)) {
        setState(
          () => _status = walletBlocked(state)
              ? _ClientInitializationStatus.recovering
              : _ClientInitializationStatus.walletRequired,
        );
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

  Future<void> _createWallet() => _runWalletOperation(WalletAction.create);
  Future<void> _importWallet() =>
      _runWalletOperation(WalletAction.importWallet);

  Future<void> _runWalletOperation(WalletAction action) async {
    final sdk = widget.sdk;
    if (_walletOperationRunning || sdk == null) return;
    setState(() => _walletOperationRunning = true);
    try {
      final committed = await showWalletDialog(
        context,
        sdk,
        action,
        _walletGone.future,
      );
      if (!mounted || !identical(sdk, widget.sdk) || !committed) return;
      await _checkWalletAndModes();
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
    final recovering = _status == _ClientInitializationStatus.recovering;
    return Scaffold(
      body: _StatusPanel(
        brand: _copy(_zh.appTitle, _en.appTitle),
        title: _copy(_zh.clientWalletTitle, _en.clientWalletTitle),
        subtitle: recovering
            ? _copy(_zh.walletRecovering, _en.walletRecovering)
            : failed
            ? _copy(
                _zh.clientWalletOperationFailed,
                _en.clientWalletOperationFailed,
              )
            : checking
            ? _copy(_zh.clientWalletChecking, _en.clientWalletChecking)
            : _copy(_zh.clientWalletSubtitle, _en.clientWalletSubtitle),
        busy: checking,
        actions: checking || _walletOperationRunning
            ? const []
            : failed || recovering
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
                TextButton(
                  key: const ValueKey('retry-wallet-check'),
                  onPressed: _checkWalletAndModes,
                  child: BilingualText(_copy(_zh.clientRetry, _en.clientRetry)),
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
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
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
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'tuyu_logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      BilingualText(
                        brand,
                        textAlign: TextAlign.center,
                        primaryStyle: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
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
                          (action) => <Widget>[
                            action,
                            const SizedBox(height: 12),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// 界面仅收集临时输入；校验、派生、提交与持久化全部归SDK。
enum WalletAction { create, importWallet }

bool walletReady(CitizenWalletState? state) =>
    state?.initializationState == CitizenWalletInitializationState.ready &&
    state?.cleanupPending == false &&
    state?.hotProfile != null;

bool walletBlocked(CitizenWalletState? state) =>
    state?.cleanupPending == true ||
    state?.initializationState == CitizenWalletInitializationState.recovering;

Future<bool> showWalletDialog(
  BuildContext context,
  CitizenSdk sdk,
  WalletAction action,
  Future<void> cancelled,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _WalletDialog(sdk: sdk, action: action, cancelled: cancelled),
    ) ??
    false;

Future<Uint8List?> requestWalletCredential(
  BuildContext context,
  CitizenCredentialChallenge challenge,
) => showDialog<Uint8List>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WalletCredential(challenge: challenge),
);

final class _WalletDialog extends StatefulWidget {
  const _WalletDialog({
    required this.sdk,
    required this.action,
    required this.cancelled,
  });
  final CitizenSdk sdk;
  final WalletAction action;
  final Future<void> cancelled;
  @override
  State<_WalletDialog> createState() => _WalletDialogState();
}

final class _WalletDialogState extends State<_WalletDialog> {
  final _password = TextEditingController();
  final _mnemonic = TextEditingController();
  CitizenWalletWordCount _wordCount = CitizenWalletWordCount.words24;
  CitizenSdkPreparedWallet? _prepared;
  CitizenSdkRecoveryPhrase? _phrase;
  CitizenSdkOperation<Object?>? _operation;
  Future<void>? _action;
  String? _error;
  bool _busy = false, _closing = false, _confirmed = false, _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.cancelled.then((_) => _cancel()));
  }

  Future<T> _run<T>(CitizenSdkOperation<T> operation) async {
    _operation = operation;
    try {
      return await operation.result;
    } finally {
      if (identical(_operation, operation)) _operation = null;
    }
  }

  Future<void> _release() async {
    await _phrase?.release();
    _phrase = null;
    await _prepared?.release();
    _prepared = null;
    if (mounted && !_disposed) {
      _password.clear();
      _mnemonic.clear();
    }
  }

  void _submit() {
    if (_busy || _closing) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _action = _perform();
    unawaited(_action!);
  }

  Future<void> _perform() async {
    try {
      final sdk = widget.sdk;
      if (_prepared != null) {
        if (!_confirmed) return;
        await _run(_prepared!.commit());
      } else {
        final password = _password.text, mnemonic = _mnemonic.text;
        final valid = await sdk.wallet.validatePassword(password);
        if (_closing || !mounted) return;
        if (!valid.isValid) {
          setState(
            () => _error = AppLocalizations.of(context).walletPasswordInvalid,
          );
          return;
        }
        if (widget.action == WalletAction.create) {
          _prepared = await _run(
            sdk.wallet.prepareCreation(
              wordCount: _wordCount,
              password: password,
            ),
          );
          if (_closing || !mounted) return;
          _phrase = await _prepared!.recoveryPhrase();
          if (_closing || !mounted) return;
          _password.clear();
          setState(() {});
          return;
        }
        final words = await sdk.wallet.validateMnemonic(mnemonic, _wordCount);
        if (_closing || !mounted) return;
        if (!words.isValid) {
          setState(
            () => _error = AppLocalizations.of(context).walletMnemonicInvalid,
          );
          return;
        }
        await _run(
          sdk.wallet.importWallet(mnemonic: mnemonic, password: password),
        );
      }
      await _release();
      if (_closing || !mounted) return;
      _closing = true;
      Navigator.of(context).pop(true);
    } on CitizenSdkException catch (error) {
      if (mounted && !_closing) {
        if (error.code == CitizenSdkErrorCode.cancelled ||
            error.code == CitizenSdkErrorCode.authenticationCancelled) {
          // 取消只等待本次动作结束后归还资源，不把它当成成功。
          scheduleMicrotask(() => unawaited(_cancel()));
        } else {
          setState(
            () =>
                _error = AppLocalizations.of(context)
                    .clientWalletOperationFailed,
          );
        }
      }
    } on Object {
      if (mounted && !_closing) {
        setState(
          () =>
              _error = AppLocalizations.of(context).clientWalletOperationFailed,
        );
      }
    } finally {
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    if (mounted && !_disposed) setState(() => _busy = true);
    try {
      await _operation?.cancel();
      await _action;
      await _release();
      if (mounted && !_disposed) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route, false);
        }
      }
    } on Object {
      _closing = false;
      if (mounted && !_disposed) {
        setState(() {
          _busy = _operation != null;
          _error = AppLocalizations.of(context).clientWalletOperationFailed;
        });
      }
    }
  }

  @override
  void dispose() {
    // 路由被外层移除时仍等待真实操作终态和资源归还。
    _disposed = true;
    unawaited(_cancel());
    _password.clear();
    _mnemonic.clear();
    _password.dispose();
    _mnemonic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context), backup = _phrase != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: AlertDialog(
        title: Text(
          backup
              ? text.walletBackup
              : widget.action == WalletAction.create
              ? text.clientCreateWallet
              : text.clientImportWallet,
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (backup) ...[
                  SelectableText(
                    utf8.decode(_phrase!.bytes),
                    key: const ValueKey('wallet-backup'),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('wallet-confirm'),
                    value: _confirmed,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    title: Text(text.walletConfirmed),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ] else ...[
                  DropdownButtonFormField<CitizenWalletWordCount>(
                    key: const ValueKey('wallet-words'),
                    initialValue: _wordCount,
                    decoration: InputDecoration(labelText: text.walletWords),
                    items: [
                      for (final count in CitizenWalletWordCount.values)
                        DropdownMenuItem(
                          value: count,
                          child: Text('${count.value}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _wordCount = value);
                            }
                          },
                  ),
                  if (widget.action != WalletAction.create)
                    TextField(
                      key: const ValueKey('wallet-mnemonic'),
                      controller: _mnemonic,
                      enabled: !_busy,
                      maxLines: 3,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration(
                        labelText: text.walletMnemonic,
                      ),
                    ),
                  TextField(
                    key: const ValueKey('wallet-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(labelText: text.walletPassword),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('wallet-cancel'),
            onPressed: _closing ? null : _cancel,
            child: Text(text.walletCancel),
          ),
          FilledButton(
            key: const ValueKey('wallet-submit'),
            onPressed: _busy || backup && !_confirmed ? null : _submit,
            child: Text(backup ? text.walletCommit : text.walletContinue),
          ),
        ],
      ),
    );
  }
}

final class _WalletCredential extends StatefulWidget {
  const _WalletCredential({required this.challenge});
  final CitizenCredentialChallenge challenge;
  @override
  State<_WalletCredential> createState() => _WalletCredentialState();
}

final class _WalletCredentialState extends State<_WalletCredential> {
  final _password = TextEditingController();
  bool _closed = false;
  @override
  void initState() {
    super.initState();
    unawaited(widget.challenge.cancelled.then((_) => _close(null)));
  }

  void _close(Uint8List? value) {
    if (_closed || !mounted) {
      value?.fillRange(0, value.length, 0);
      return;
    }
    _closed = true;
    _password.clear();
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route, value);
    }
  }

  @override
  void dispose() {
    _closed = true;
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(null);
      },
      child: AlertDialog(
        title: Text(text.walletCredential),
        content: TextField(
          key: const ValueKey('wallet-credential'),
          controller: _password,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: text.walletPassword),
        ),
        actions: [
          TextButton(
            onPressed: () => _close(null),
            child: Text(text.walletCancel),
          ),
          FilledButton(
            onPressed: () =>
                _close(Uint8List.fromList(utf8.encode(_password.text))),
            child: Text(text.walletContinue),
          ),
        ],
      ),
    );
  }
}
