import 'package:flutter/material.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/restaurant/restaurant_controller.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';
import 'package:tuyubooking/client/restaurant/restaurant_payment_page.dart';

final class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({required this.controller, super.key});
  final RestaurantController controller;

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

final class _RestaurantOrdersPageState extends State<RestaurantOrdersPage> {
  static const _title = BilingualCopy(zh: '餐厅订单', en: 'Restaurant orders');
  static const _draft = BilingualCopy(zh: '草稿', en: 'Draft');
  static const _unbilled = BilingualCopy(zh: '未结账', en: 'Unbilled');
  static const _paid = BilingualCopy(zh: '最近支付', en: 'Recently paid');
  static const _empty = BilingualCopy(zh: '没有相关订单', en: 'No matching orders');
  static const _open = BilingualCopy(zh: '打开订单', en: 'Open order');
  static const _checkout = BilingualCopy(zh: '收银', en: 'Payment');

  @override
  void initState() {
    super.initState();
    widget.controller.loadOrders();
  }

  Future<void> _openOrder(RestaurantOrderReceipt order) async {
    await widget.controller.selectOrder(order);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const BilingualText(_title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Draft', label: BilingualText(_draft)),
                  ButtonSegment(
                    value: 'Unbilled',
                    label: BilingualText(_unbilled),
                  ),
                  ButtonSegment(
                    value: 'Recently Paid',
                    label: BilingualText(_paid),
                  ),
                ],
                selected: {widget.controller.orderStatus},
                onSelectionChanged: (selection) =>
                    widget.controller.loadOrders(statusFilter: selection.first),
              ),
            ),
            Expanded(
              child: widget.controller.ordersLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.controller.orders.isEmpty
                  ? const Center(child: BilingualText(_empty))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: widget.controller.orders.length,
                      itemBuilder: (context, index) {
                        final order = widget.controller.orders[index];
                        final currency =
                            widget.controller.profile?.currency ?? '';
                        return Card(
                          child: ListTile(
                            title: Text(order.name),
                            subtitle: Text(
                              '${order.table.isEmpty ? order.status : order.table} · '
                              '$currency ${order.roundedTotal.toStringAsFixed(2)}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _openOrder(order),
                                  child: const BilingualText(_open),
                                ),
                                if (order.status != 'Paid' &&
                                    order.status != 'Recently Paid')
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => RestaurantPaymentPage(
                                          controller: widget.controller,
                                          order: order,
                                        ),
                                      ),
                                    ),
                                    child: const BilingualText(_checkout),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
