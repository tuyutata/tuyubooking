import 'package:flutter/material.dart';
import 'package:tuyubooking/host/route_atlas_ui.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/qr/qr_code_view.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';

enum AdministratorSignatureMode { initialization, login }

/// Shared optical exchange: request QR out, signed response through camera in.
/// TuyuBooking never receives or stores an administrator private key.
final class SignatureExchangeView extends StatelessWidget {
  const SignatureExchangeView({
    required this.mode,
    required this.challengePayload,
    required this.challengeIdentity,
    required this.scanner,
    required this.onScanned,
    required this.failed,
    required this.onNewChallenge,
    required this.titleKey,
    required this.challengeQrKey,
    required this.cameraKey,
    this.form,
    super.key,
  });

  static const _initializeTitle = BilingualCopy(
    zh: '设置管理员',
    en: 'Set administrator',
  );
  static const _loginTitle = BilingualCopy(
    zh: '管理员登录',
    en: 'Administrator sign-in',
  );
  static const _loginSubtitle = BilingualCopy(
    zh: '扫码签名，安全登录',
    en: 'Scan and sign to continue',
  );
  static const _initializeEyebrow = BilingualCopy(
    zh: '01 / 初始化',
    en: '01 / INITIALIZE',
  );
  static const _loginEyebrow = BilingualCopy(zh: '管理员验证', en: 'ADMIN ACCESS');
  static const _signatureQr = BilingualCopy(zh: '签名二维码', en: 'SIGNATURE QR');
  static const _scan = BilingualCopy(zh: '扫码识别', en: 'SCAN');
  static const _preparing = BilingualCopy(zh: '准备摄像头', en: 'Starting camera');
  static const _scanning = BilingualCopy(zh: '对准签名二维码', en: 'Show signed QR');
  static const _verifying = BilingualCopy(zh: '正在验签', en: 'Verifying');
  static const _waiting = BilingualCopy(
    zh: '等待签名',
    en: 'Waiting for signature',
  );
  static const _cameraUnavailable = BilingualCopy(
    zh: '无法使用摄像头',
    en: 'Camera unavailable',
  );
  static const _invalidSignature = BilingualCopy(
    zh: '签名无效，请刷新二维码重试',
    en: 'Invalid signature. Refresh the QR and try again',
  );
  static const _refresh = BilingualCopy(zh: '刷新二维码', en: 'Refresh QR');

  final AdministratorSignatureMode mode;
  final String? challengePayload;
  final String? challengeIdentity;
  final EmbeddedQrScanner? scanner;
  final EmbeddedQrScanCallback onScanned;
  final bool failed;
  final Future<void> Function() onNewChallenge;
  final Key titleKey;
  final Key challengeQrKey;
  final Key cameraKey;
  final Widget? form;

  @override
  Widget build(BuildContext context) {
    final initialization = mode == AdministratorSignatureMode.initialization;
    final title = initialization ? _initializeTitle : _loginTitle;
    final eyebrow = initialization ? _initializeEyebrow : _loginEyebrow;
    return TuyuRouteAtlasShell(
      activeStep: initialization ? 1 : null,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 790),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BilingualText(
                  eyebrow,
                  textAlign: TextAlign.center,
                  primaryStyle: const TextStyle(
                    color: TuyuRouteAtlasPalette.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                  secondaryStyle: const TextStyle(
                    color: TuyuRouteAtlasPalette.muted,
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                BilingualText(
                  title,
                  key: titleKey,
                  textAlign: TextAlign.center,
                  primaryStyle: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(
                        color: TuyuRouteAtlasPalette.ivory,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                  secondaryStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(
                        color: TuyuRouteAtlasPalette.amber,
                        letterSpacing: 1,
                      ),
                ),
                if (!initialization) ...[
                  const SizedBox(height: 8),
                  const BilingualText(
                    _loginSubtitle,
                    textAlign: TextAlign.center,
                    primaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.ivory,
                      fontSize: 15,
                    ),
                    secondaryStyle: TextStyle(
                      color: TuyuRouteAtlasPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
                if (form != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: TuyuRouteAtlasPalette.amber,
                          onSurface: TuyuRouteAtlasPalette.ivory,
                        ),
                        textTheme: Theme.of(context).textTheme.apply(
                          bodyColor: TuyuRouteAtlasPalette.ivory,
                          displayColor: TuyuRouteAtlasPalette.ivory,
                        ),
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: const Color(0x40123e32),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0x80d5a95d),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0x66c7d2be),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: TuyuRouteAtlasPalette.amber,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      child: form!,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final request = _ExchangePanel(
                      key: const ValueKey('signature-request-panel'),
                      step: '1',
                      title: _signatureQr,
                      child: _requestSurface(),
                    );
                    final response = _ExchangePanel(
                      key: const ValueKey('signature-response-panel'),
                      step: '2',
                      title: _scan,
                      child: _cameraSurface(context),
                    );
                    if (constraints.maxWidth < 700) {
                      final extent = constraints.maxWidth
                          .clamp(280.0, 360.0)
                          .toDouble();
                      return Column(
                        children: [
                          SizedBox.square(dimension: extent, child: request),
                          const SizedBox(height: 22),
                          SizedBox.square(dimension: extent, child: response),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: request),
                        const SizedBox(width: 28),
                        Expanded(child: response),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _SignatureStatusBar(failed: failed, onRefresh: onNewChallenge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestSurface() {
    final payload = challengePayload;
    if (payload == null) return const _SignaturePlaceholder();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: QrCodeView(key: challengeQrKey, data: payload),
      ),
    );
  }

  Widget _cameraSurface(BuildContext context) {
    final currentScanner = scanner;
    if (challengePayload == null) return const _SignaturePlaceholder();
    if (currentScanner == null) {
      return const _CameraUnavailable(copy: _cameraUnavailable);
    }
    return ClipRRect(
      key: cameraKey,
      borderRadius: BorderRadius.circular(12),
      child: currentScanner.buildEmbedded(
        key: ValueKey(challengeIdentity),
        onScanned: onScanned,
        preparingMessage: _preparing.primary(context),
        preparingSecondaryMessage: _preparing.secondary(context),
        scanningMessage: _scanning.primary(context),
        scanningSecondaryMessage: _scanning.secondary(context),
        recognizedMessage: _verifying.primary(context),
        recognizedSecondaryMessage: _verifying.secondary(context),
        unavailableMessage: _cameraUnavailable.primary(context),
        unavailableSecondaryMessage: _cameraUnavailable.secondary(context),
      ),
    );
  }
}

final class _ExchangePanel extends StatelessWidget {
  const _ExchangePanel({
    required this.step,
    required this.title,
    required this.child,
    super.key,
  });

  final String step;
  final BilingualCopy title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe6123e32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x99d5a95d)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: TuyuRouteAtlasPalette.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: TuyuRouteAtlasPalette.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                BilingualText(
                  title,
                  primaryStyle: const TextStyle(
                    color: TuyuRouteAtlasPalette.ivory,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  secondaryStyle: const TextStyle(
                    color: TuyuRouteAtlasPalette.amber,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: SizedBox.square(dimension: 224, child: child)),
          ],
        ),
      ),
    ),
  );
}

final class _SignatureStatusBar extends StatelessWidget {
  const _SignatureStatusBar({required this.failed, required this.onRefresh});

  final bool failed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xb3123e32),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: failed ? const Color(0x99f1a387) : const Color(0x55c7d2be),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: failed
                  ? TuyuRouteAtlasPalette.danger
                  : TuyuRouteAtlasPalette.eucalyptus,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x66c7d2be), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BilingualText(
              failed
                  ? SignatureExchangeView._invalidSignature
                  : SignatureExchangeView._waiting,
              key: failed ? const ValueKey('signature-error') : null,
              primaryStyle: TextStyle(
                color: failed
                    ? TuyuRouteAtlasPalette.danger
                    : TuyuRouteAtlasPalette.ivory,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              secondaryStyle: const TextStyle(
                color: TuyuRouteAtlasPalette.muted,
                fontSize: 9,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRefresh,
            style: TextButton.styleFrom(
              foregroundColor: TuyuRouteAtlasPalette.amber,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const BilingualText(
              SignatureExchangeView._refresh,
              maxLines: 1,
              primaryStyle: TextStyle(
                color: TuyuRouteAtlasPalette.amber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              secondaryStyle: TextStyle(
                color: TuyuRouteAtlasPalette.muted,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _SignaturePlaceholder extends StatelessWidget {
  const _SignaturePlaceholder();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0x33123e32),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    child: Center(
      child: CircularProgressIndicator(color: TuyuRouteAtlasPalette.amber),
    ),
  );
}

final class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.copy});

  final BilingualCopy copy;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: TuyuRouteAtlasPalette.ink,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BilingualText(
          copy,
          textAlign: TextAlign.center,
          primaryStyle: const TextStyle(
            color: TuyuRouteAtlasPalette.ivory,
            fontWeight: FontWeight.w700,
          ),
          secondaryStyle: const TextStyle(
            color: TuyuRouteAtlasPalette.muted,
            fontSize: 10,
          ),
        ),
      ),
    ),
  );
}
