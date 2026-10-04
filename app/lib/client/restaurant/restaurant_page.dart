import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/restaurant/restaurant_cart_page.dart';
import 'package:tuyubooking/client/restaurant/restaurant_controller.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';
import 'package:tuyubooking/client/restaurant/restaurant_orders_page.dart';
import 'package:tuyubooking/client/restaurant/restaurant_repository.dart';

final class RestaurantPage extends StatefulWidget {
  const RestaurantPage({
    required this.session,
    required this.onSignOut,
    super.key,
  });

  final EmployeeSession session;
  final Future<void> Function() onSignOut;

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

final class _RestaurantPageState extends State<RestaurantPage> {
  static const _title = BilingualCopy(zh: '餐厅点餐', en: 'Restaurant ordering');
  static const _retry = BilingualCopy(zh: '重新加载', en: 'Reload');
  static const _failed = BilingualCopy(
    zh: '无法读取餐厅配置，请检查员工权限和 POS 配置。',
    en: 'Restaurant configuration could not be loaded. Check employee permissions and the POS profile.',
  );
  static const _all = BilingualCopy(zh: '全部', en: 'All');
  static const _cart = BilingualCopy(zh: '查看订单', en: 'View order');
  static const _signOut = BilingualCopy(zh: '退出', en: 'Sign out');
  static const _orders = BilingualCopy(zh: '订单', en: 'Orders');
  static const _quantity = BilingualCopy(zh: '数量', en: 'Quantity');
  static const _note = BilingualCopy(zh: '备注', en: 'Note');
  static const _variants = BilingualCopy(zh: '规格', en: 'Variants');
  static const _addOns = BilingualCopy(zh: '加料', en: 'Add-ons');
  static const _add = BilingualCopy(zh: '加入订单', en: 'Add to order');
  static const _cancel = BilingualCopy(zh: '取消', en: 'Cancel');

  late final RestaurantController _controller = RestaurantController(
    RestaurantRepository(widget.session),
  );

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _configureItem(RestaurantMenuItem item) async {
    RestaurantItemOptions options;
    try {
      options = await _controller.loadOptions(item);
    } on Object {
      options = const RestaurantItemOptions(variants: [], addOns: []);
    }
    if (!mounted) return;
    var selectedItem = item;
    var quantity = 1;
    final selectedAddOns = <String>{};
    final note = TextEditingController();
    final variants = <RestaurantMenuItem>[
      item,
      ...options.variants.where((variant) => variant.code != item.code),
    ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item.name),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (variants.length > 1) ...[
                    const BilingualText(_variants),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: variants
                          .map(
                            (variant) => ChoiceChip(
                              label: Text(
                                '${variant.name} ${variant.price.toStringAsFixed(2)}',
                              ),
                              selected: selectedItem.code == variant.code,
                              onSelected: (_) =>
                                  setDialogState(() => selectedItem = variant),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (options.addOns.isNotEmpty) ...[
                    const BilingualText(_addOns),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: options.addOns
                          .map(
                            (addOn) => FilterChip(
                              label: Text(
                                '${addOn.name} +${addOn.price.toStringAsFixed(2)}',
                              ),
                              selected: selectedAddOns.contains(addOn.code),
                              onSelected: (selected) => setDialogState(() {
                                selected
                                    ? selectedAddOns.add(addOn.code)
                                    : selectedAddOns.remove(addOn.code);
                              }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      const Expanded(child: BilingualText(_quantity)),
                      IconButton(
                        onPressed: quantity > 1
                            ? () => setDialogState(() => quantity -= 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$quantity'),
                      IconButton(
                        onPressed: quantity < 99
                            ? () => setDialogState(() => quantity += 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: BilingualText(_note),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const BilingualText(_cancel),
            ),
            FilledButton(
              onPressed: () {
                _controller.addConfiguredItem(
                  item: selectedItem,
                  quantity: quantity.toDouble(),
                  comment: note.text.trim(),
                  addOns: options.addOns
                      .where((addOn) => selectedAddOns.contains(addOn.code))
                      .toList(growable: false),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const BilingualText(_add),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          title: const BilingualText(_title),
          actions: [
            Center(child: Text(widget.session.identity)),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RestaurantOrdersPage(controller: _controller),
                ),
              ),
              child: const BilingualText(_orders),
            ),
            TextButton(
              onPressed: widget.onSignOut,
              child: const BilingualText(_signOut),
            ),
          ],
        ),
        body: SafeArea(child: _body(context)),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RestaurantCartPage(controller: _controller),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: BilingualText(
                      BilingualCopy(
                        zh: '${_cart.zh}（${_controller.itemCount}）',
                        en: '${_cart.en} (${_controller.itemCount})',
                      ),
                    ),
                  ),
                ),
              )
            : null,
      );
    },
  );

  Widget _body(BuildContext context) {
    if (_controller.status == RestaurantStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.status == RestaurantStatus.failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BilingualText(_failed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _controller.initialize,
              child: const BilingualText(_retry),
            ),
          ],
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final controls = _RestaurantContextPanel(controller: _controller);
    final menu = _menuPanel(context);
    if (!wide) {
      return Column(
        children: [
          controls,
          Expanded(child: menu),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 250, child: controls),
        const VerticalDivider(width: 1),
        Expanded(child: menu),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 390,
          child: RestaurantCartPanel(controller: _controller),
        ),
      ],
    );
  }

  Widget _menuPanel(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 58,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _controller.selectedCategory == null,
                onSelected: (_) => _controller.selectCategory(null),
                label: const BilingualText(_all),
              ),
            ),
            ..._controller.categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _controller.selectedCategory == category.name,
                  onSelected: (_) => _controller.selectCategory(category.name),
                  label: Text(category.label),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 3
                : 2;
            return GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: _controller.filteredMenu.length,
              itemBuilder: (context, index) {
                final item = _controller.filteredMenu[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _configureItem(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.specialDish
                                ? Icons.local_fire_department_outlined
                                : Icons.restaurant_menu_rounded,
                          ),
                          const Spacer(),
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_controller.profile!.currency} ${item.price.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

final class _RestaurantContextPanel extends StatelessWidget {
  const _RestaurantContextPanel({required this.controller});

  static const _type = BilingualCopy(zh: '订单方式', en: 'Order type');
  static const _dineIn = BilingualCopy(zh: '堂食', en: 'Dine in');
  static const _takeAway = BilingualCopy(zh: '外带', en: 'Take away');
  static const _room = BilingualCopy(zh: '区域', en: 'Room');
  static const _table = BilingualCopy(zh: '桌台', en: 'Table');
  static const _guests = BilingualCopy(zh: '用餐人数', en: 'Guests');

  final RestaurantController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BilingualText(_type),
        const SizedBox(height: 8),
        SegmentedButton<RestaurantOrderType>(
          segments: const [
            ButtonSegment(
              value: RestaurantOrderType.takeAway,
              label: BilingualText(_takeAway),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
            ButtonSegment(
              value: RestaurantOrderType.dineIn,
              label: BilingualText(_dineIn),
              icon: Icon(Icons.table_restaurant_outlined),
            ),
          ],
          selected: {controller.orderType},
          onSelectionChanged: (selection) =>
              controller.selectOrderType(selection.first),
        ),
        if (controller.orderType == RestaurantOrderType.dineIn) ...[
          const SizedBox(height: 18),
          const BilingualText(_room),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: controller.selectedRoom,
            items: controller.rooms
                .map(
                  (room) => DropdownMenuItem(
                    value: room.name,
                    child: Text(room.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (room) {
              if (room != null) controller.selectRoom(room);
            },
          ),
          const SizedBox(height: 18),
          const BilingualText(_table),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.tables
                .map(
                  (table) => ChoiceChip(
                    label: Text(table.name),
                    selected: controller.selectedTable == table.name,
                    onSelected: (_) => controller.selectTable(table.name),
                    avatar: Icon(
                      table.occupied
                          ? Icons.lock_outline
                          : Icons.chair_outlined,
                      size: 18,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: BilingualText(_guests)),
              IconButton(
                onPressed: controller.numberOfGuests > 1
                    ? () => controller.setNumberOfGuests(
                        controller.numberOfGuests - 1,
                      )
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${controller.numberOfGuests}'),
              IconButton(
                onPressed: () =>
                    controller.setNumberOfGuests(controller.numberOfGuests + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
