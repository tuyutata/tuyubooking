import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';
import 'package:tuyubooking/host/authentication/auth_model.dart';
import 'package:tuyubooking/host/authentication/signature_exchange_view.dart';

final class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends State<LoginPage> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (!_requested && auth.status == AuthStatus.idle) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => auth.createLoginChallenge(),
      );
    }
  }

  Future<void> _completeLogin(String rawQr) async {
    if (!mounted) return;
    await context.read<AuthController>().completeLoginQr(rawQr);
  }

  Future<void> _newChallenge() async {
    final auth = context.read<AuthController>();
    auth.retry();
    await auth.createLoginChallenge();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final challenge = auth.challenge;
    final scanner = context.read<QrScanner>();
    final embeddedScanner = scanner is EmbeddedQrScanner
        ? scanner as EmbeddedQrScanner
        : null;
    return SignatureExchangeView(
      mode: AdministratorSignatureMode.login,
      challengePayload: challenge?.toQrPayload(),
      challengeIdentity: challenge?.requestId,
      scanner: embeddedScanner,
      onScanned: _completeLogin,
      failed: auth.status == AuthStatus.failed,
      onNewChallenge: _newChallenge,
      titleKey: const ValueKey('administrator-login-title'),
      challengeQrKey: const ValueKey('login-challenge-qr'),
      cameraKey: const ValueKey('login-signature-camera'),
    );
  }
}
