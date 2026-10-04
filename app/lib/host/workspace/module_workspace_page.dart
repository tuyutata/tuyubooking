import 'package:flutter/material.dart';

final class ModuleWorkspacePage extends StatelessWidget {
  const ModuleWorkspacePage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.capabilities,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: capabilities
                .map(
                  (value) => Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}
