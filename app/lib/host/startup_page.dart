import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class StartupPage extends StatelessWidget {
  const StartupPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final runtime = context.watch<RuntimeController>();
    final error = runtime.error;
    final message = error is NativeBridgeException
        ? error.localized(Localizations.localeOf(context).languageCode)
        : strings.startupError;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.travel_explore,
                  size: 64,
                  color: Color(0xffa43d24),
                ),
                const SizedBox(height: 18),
                Text(
                  strings.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (runtime.status == RuntimeStatus.failed) ...[
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: runtime.start,
                    child: Text(strings.retry),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(strings.startingLocalService),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
