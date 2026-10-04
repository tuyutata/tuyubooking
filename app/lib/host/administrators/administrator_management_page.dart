import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/host/administrators/administrator_controller.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class AdministratorManagementPage extends StatefulWidget {
  const AdministratorManagementPage({super.key});

  @override
  State<AdministratorManagementPage> createState() =>
      _AdministratorManagementPageState();
}

final class _AdministratorManagementPageState
    extends State<AdministratorManagementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AdministratorController>().load(),
    );
  }

  Future<String?> _nameDialog({String? initial}) async {
    final strings = AppLocalizations.of(context);
    final field = TextEditingController(text: initial);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.administratorName),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(helperText: strings.optionalField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    field.dispose();
    return result;
  }

  Future<void> _add() async {
    final strings = AppLocalizations.of(context);
    final name = await _nameDialog();
    if (name == null || !mounted) return;
    final rawQr = await context.read<QrScanner>().scan(
      context,
      title: strings.scanAdministratorPublicKey,
      instruction: strings.publicKeyScanInstruction,
      unavailableMessage: strings.cameraUnavailable,
      cancelLabel: strings.cancel,
    );
    if (rawQr == null || !mounted) return;
    await context.read<AdministratorController>().add(
      publicKeyQr: rawQr,
      name: name,
    );
  }

  Future<void> _rename(AdministratorSnapshot administrator) async {
    final name = await _nameDialog(initial: administrator.name);
    if (name == null || !mounted) return;
    await context.read<AdministratorController>().rename(
      administrator.id,
      name,
    );
  }

  Future<void> _delete(AdministratorSnapshot administrator) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteAdministrator),
        content: Text(strings.deleteAdministratorConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.deleteAdministrator),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AdministratorController>().delete(administrator.id);
    if (mounted &&
        context.read<AuthController>().nativeSession == null &&
        Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final controller = context.watch<AdministratorController>();
    final currentId = context
        .watch<AuthController>()
        .nativeSession
        ?.administratorId;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.administratorManagement),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const ValueKey('add-administrator'),
              onPressed:
                  controller.isBusy || controller.administrators.length >= 99
                  ? null
                  : _add,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(strings.addAdministrator),
            ),
          ),
        ],
      ),
      body: controller.status == AdministratorManagementStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(28),
              itemCount: controller.administrators.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.administratorPolicySummary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (controller.error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          strings.administratorOperationFailed,
                          style: const TextStyle(color: Color(0xffa43d24)),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  );
                }
                final administrator = controller.administrators[index - 1];
                final isCurrent = administrator.id == currentId;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      child: Icon(
                        administrator.isActive
                            ? Icons.verified_user_outlined
                            : Icons.person_off_outlined,
                      ),
                    ),
                    title: Text(
                      administrator.name?.isNotEmpty == true
                          ? administrator.name!
                          : strings.unnamedAdministrator,
                    ),
                    subtitle: Text(
                      '${administrator.publicKey.substring(0, 12)}...${administrator.publicKey.substring(administrator.publicKey.length - 8)}'
                      '${isCurrent ? ' · ${strings.currentAdministrator}' : ''}',
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Switch(
                          value: administrator.isActive,
                          onChanged: controller.isBusy
                              ? null
                              : (active) => controller.setStatus(
                                  administrator.id,
                                  active,
                                ),
                        ),
                        IconButton(
                          tooltip: strings.renameAdministrator,
                          onPressed: controller.isBusy
                              ? null
                              : () => _rename(administrator),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: strings.deleteAdministrator,
                          onPressed: controller.isBusy
                              ? null
                              : () => _delete(administrator),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
