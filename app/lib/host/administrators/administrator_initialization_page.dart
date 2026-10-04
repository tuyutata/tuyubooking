import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';
import 'package:tuyubooking/host/authentication/auth_model.dart';
import 'package:tuyubooking/host/authentication/signature_exchange_view.dart';

final class AdministratorInitializationPage extends StatefulWidget {
  const AdministratorInitializationPage({super.key});

  @override
  State<AdministratorInitializationPage> createState() =>
      _AdministratorInitializationPageState();
}

final class _AdministratorInitializationPageState
    extends State<AdministratorInitializationPage> {
  static const _nameCopy = BilingualCopy(
    zh: '管理员姓名（选填）',
    en: 'Name (optional)',
  );
  final TextEditingController _name = TextEditingController();
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (!_requested && auth.status == AuthStatus.requiresInitialization) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => auth.createInitializationChallenge(),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _completeInitialization(String rawQr) async {
    if (!mounted) return;
    await context.read<AuthController>().initializeAdministrator(
      signedResponseQr: rawQr,
      name: _name.text,
    );
  }

  Future<void> _newChallenge() async {
    final auth = context.read<AuthController>();
    auth.retry();
    await auth.createInitializationChallenge();
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
      mode: AdministratorSignatureMode.initialization,
      challengePayload: challenge?.toQrPayload(),
      challengeIdentity: challenge?.requestId,
      scanner: embeddedScanner,
      onScanned: _completeInitialization,
      failed: auth.status == AuthStatus.failed,
      onNewChallenge: _newChallenge,
      titleKey: const ValueKey('administrator-initialization-title'),
      challengeQrKey: const ValueKey(
        'administrator-initialization-challenge-qr',
      ),
      cameraKey: const ValueKey('administrator-signature-camera'),
      form: SizedBox(
        width: 400,
        child: TextField(
          key: const ValueKey('administrator-name-field'),
          controller: _name,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.badge_outlined),
            label: BilingualText(_nameCopy, maxLines: 1),
            counterText: '',
          ),
        ),
      ),
    );
  }
}
