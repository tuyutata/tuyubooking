import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/restaurant/restaurant_controller.dart';
import 'package:tuyubooking/client/restaurant/restaurant_payment_page.dart';

final class RestaurantCartPage extends StatelessWidget {
  const RestaurantCartPage({required this.controller, super.key});

  static const _cart = BilingualCopy(zh: '当前订单', en: 'Current order');

  final RestaurantController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BilingualText(_cart)),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => RestaurantCartPanel(controller: controller),
      ),
    ),
  );
}

final class RestaurantCartPanel extends StatelessWidget {
  const RestaurantCartPanel({required this.controller, super.key});

  static const _empty = BilingualCopy(
    zh: '还没有添加菜品',
    en: 'No items have been added',
  );
  static const _addOn = BilingualCopy(zh: '加料', en: 'Add-on');
  static const _total = BilingualCopy(zh: '合计', en: 'Total');
  static const _clear = BilingualCopy(zh: '清空', en: 'Clear');
  static const _submitLabel = BilingualCopy(zh: '提交订单', en: 'Submit order');
  static const _submitting = BilingualCopy(zh: '正在提交', en: 'Submitting');
  static const _chooseTable = BilingualCopy(
    zh: '堂食订单必须先选择桌台。',
    en: 'Select a table before submitting a dine-in order.',
  );
  static const _failed = BilingualCopy(
    zh: '订单提交失败，请检查权限、桌台状态或重新加载。',
    en: 'Order submission failed. Check permissions, table state, or reload.',
  );
  static const _success = BilingualCopy(zh: '订单已提交', en: 'Order submitted');
  static const _saved = BilingualCopy(zh: '已保存订单', en: 'Saved order');
  static const _payment = BilingualCopy(zh: '进入收银', en: 'Proceed to payment');

  final RestaurantController controller;

  Future<void> _submit(BuildContext context) async {
    if (!controller.canSubmit) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: BilingualText(_chooseTable)));
      return;
    }
    final receipt = await controller.submit();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: BilingualText(receipt == null ? _failed : _success)),
    );
    if (receipt != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = controller.profile?.currency ?? '';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: BilingualText(
                  _total,
                  primaryStyle: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '$currency ${controller.total.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Divider(height: 28),
          if (controller.activeOrder != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const BilingualText(_saved),
              subtitle: Text(controller.activeOrder!.name),
              trailing: FilledButton(
                onPressed: controller.hasUnsavedChanges
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantPaymentPage(
                            controller: controller,
                            order: controller.activeOrder!,
                          ),
                        ),
                      ),
                child: const BilingualText(_payment),
              ),
            ),
            const Divider(),
          ],
          Expanded(
            child: controller.cart.isEmpty
                ? const Center(
                    child: BilingualText(_empty, textAlign: TextAlign.center),
                  )
                : ListView.separated(
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final line = controller.cart[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.item.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (line.isAddOn) const BilingualText(_addOn),
                            if (line.comment.isNotEmpty) Text(line.comment),
                            Text('$currency ${line.amount.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  controller.changeQuantity(index, -1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(line.quantity.toStringAsFixed(0)),
                            IconButton(
                              onPressed: () =>
                                  controller.changeQuantity(index, 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: controller.cart.isEmpty
                    ? null
                    : controller.clearCart,
                child: const BilingualText(_clear),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.cart.isEmpty
                      ? null
                      : () => _submit(context),
                  icon: controller.status == RestaurantStatus.submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: BilingualText(
                    controller.status == RestaurantStatus.submitting
                        ? _submitting
                        : _submitLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
