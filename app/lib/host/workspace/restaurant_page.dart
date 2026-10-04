import 'package:flutter/material.dart';
import 'package:tuyubooking/host/workspace/module_workspace_page.dart';
import 'package:tuyubooking/shared/localization/generated/app_localizations.dart';

final class RestaurantPage extends StatelessWidget {
  const RestaurantPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ModuleWorkspacePage(
      title: s.restaurant,
      subtitle: s.restaurantSubtitle,
      icon: Icons.restaurant_outlined,
      capabilities: [s.tables, s.menu, s.restaurantOrders],
    );
  }
}
