import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/employee_access/adapters/hi_events_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/kamra_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/ury_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/adapters/voyant_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_auth_adapter.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/employee_access/employee_session_page.dart';

final class EmployeeLoginPage extends StatefulWidget {
  const EmployeeLoginPage({
    required this.profile,
    required this.module,
    this.adapter,
    super.key,
  });

  final EmployeeHostProfile profile;
  final EmployeeBusinessModule module;
  final EmployeeAuthAdapter? adapter;

  @override
  State<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

final class _EmployeeLoginPageState extends State<EmployeeLoginPage> {
  static const _signIn = BilingualCopy(zh: '员工登录', en: 'Employee sign in');
  static const _password = BilingualCopy(zh: '密码', en: 'Password');
  static const _submit = BilingualCopy(zh: '登录', en: 'Sign in');
  static const _working = BilingualCopy(zh: '正在登录', en: 'Signing in');
  static const _required = BilingualCopy(
    zh: '请输入员工账户和密码。',
    en: 'Enter your employee account and password.',
  );
  static const _invalid = BilingualCopy(
    zh: '员工账户或密码不正确。',
    en: 'The employee account or password is incorrect.',
  );
  static const _unavailable = BilingualCopy(
    zh: '当前无法连接业务子系统，请稍后重试。',
    en: 'The business subsystem is unavailable. Try again shortly.',
  );
  static const _invalidResponse = BilingualCopy(
    zh: '业务子系统返回了无效的登录结果。',
    en: 'The business subsystem returned an invalid sign-in result.',
  );
  static const _privacy = BilingualCopy(
    zh: '密码只发送到当前商家的本地主机，不会保存到设备。',
    en: 'Your password is sent only to this merchant host and is not stored.',
  );

  final _identifier = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  BilingualCopy? _error;

  EmployeeAuthAdapter get _adapter => widget.adapter ?? switch (widget.module) {
    EmployeeBusinessModule.hotel => const KamraAuthAdapter(),
    EmployeeBusinessModule.restaurant => const UryAuthAdapter(),
    EmployeeBusinessModule.tour => const VoyantAuthAdapter(),
    EmployeeBusinessModule.ticket => const HiEventsAuthAdapter(),
  };

  @override
  void dispose() {
    _identifier.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInEmployee() async {
    if (_submitting) return;
    if (!widget.profile.routes.contains(widget.module.route)) {
      setState(() => _error = _unavailable);
      return;
    }
    final identifier = _identifier.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = _required);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final profile = widget.profile;
    final module = widget.module;
    // 密码不留在输入框或系统自动填充保存流程中，仅供本次上游登录请求使用。
    _passwordController.clear();
    try {
      final session = await _adapter.signIn(
        profile: profile,
        identifier: identifier,
        password: password,
      );
      if (!mounted) {
        session.dispose();
        return;
      }
      if (!identical(profile, widget.profile) || module != widget.module || session.module != module) {
        session.dispose();
        setState(() => _error = _invalidResponse);
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmployeeSessionPage(session: session),
        ),
      );
    } on EmployeeAuthenticationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.failure) {
          EmployeeAuthenticationFailure.invalidCredentials => _invalid,
          EmployeeAuthenticationFailure.invalidResponse => _invalidResponse,
          EmployeeAuthenticationFailure.serviceUnavailable => _unavailable,
        };
      });
    } on Object {
      if (mounted) setState(() => _error = _unavailable);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: BilingualText(widget.module.title)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  onDisposeAction: AutofillContextAction.cancel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.badge_outlined, size: 54),
                      const SizedBox(height: 18),
                      BilingualText(
                        _signIn,
                        textAlign: TextAlign.center,
                        primaryStyle: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.profile.merchantName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _identifier,
                        enabled: !_submitting,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          label: BilingualText(widget.module.identifier),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        enabled: !_submitting,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signInEmployee(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          label: BilingualText(_password),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        BilingualText(
                          _error!,
                          primaryStyle: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                          secondaryStyle: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _signInEmployee,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: BilingualText(_submitting ? _working : _submit),
                      ),
                      const SizedBox(height: 16),
                      const BilingualText(
                        _privacy,
                        textAlign: TextAlign.center,
                      ),
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
