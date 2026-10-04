import 'package:flutter/material.dart';
import 'package:tuyubooking/host/workspace/module_workspace_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class TourPage extends StatelessWidget {
  const TourPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ModuleWorkspacePage(
      title: s.tour,
      subtitle: s.tourSubtitle,
      icon: Icons.route_outlined,
      capabilities: [s.itineraries, s.departures, s.travelers],
    );
  }
}
