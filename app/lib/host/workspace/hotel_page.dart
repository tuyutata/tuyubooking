import 'package:flutter/material.dart';
import 'package:tuyubooking/host/workspace/module_workspace_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class HotelPage extends StatelessWidget {
  const HotelPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ModuleWorkspacePage(
      title: s.hotel,
      subtitle: s.hotelSubtitle,
      icon: Icons.hotel_outlined,
      capabilities: [s.roomInventory, s.roomRates, s.hotelDining],
    );
  }
}
