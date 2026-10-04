import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuyubooking/shared/localization/bilingual_text.dart';
import 'package:tuyubooking/client/restaurant/restaurant_controller.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';
import 'package:tuyubooking/client/restaurant/restaurant_repository.dart';

final class RestaurantPaymentPage extends StatefulWidget {
  const RestaurantPaymentPage({
    required this.controller,
    required this.order,
    super.key,
  });

  final RestaurantController controller;
  final RestaurantOrderReceipt order;

  @override
  State<RestaurantPaymentPage> createState() => _RestaurantPaymentPageState();
}

final class _RestaurantPaymentPageState extends State<RestaurantPaymentPage> {
  static const _title = BilingualCopy(zh: '订单收银', en: 'Order payment');
  static const _methods = BilingualCopy(zh: '支付方式', en: 'Payment methods');
  static const _total = BilingualCopy(zh: '应收金额', en: 'Amount due');
  static const _entered = BilingualCopy(zh: '已输入金额', en: 'Entered amount');
  static const _pay = BilingualCopy(zh: '确认收款', en: 'Confirm payment');
  static const _processing = BilingualCopy(zh: '正在收款', en: 'Processing');
  static const _noModes = BilingualCopy(
    zh: '当前 POS Profile 没有配置支付方式。',
    en: 'No payment methods are configured for this POS Profile.',
  );
  static const _short = BilingualCopy(
    zh: '输入的收款金额不足。',
    en: 'The entered payment amount is insufficient.',
  );
  static const _opening = BilingualCopy(
    zh: '当前员工尚未完成 POS 开班，不能收银。',
    en: 'This employee has no open POS shift and cannot take payment.',
  );
  static const _failed = BilingualCopy(
    zh: '收银失败，请检查权限和订单状态。',
    en: 'Payment failed. Check permissions and order status.',
  );

  final Map<String, TextEditingController> _amounts = {};
  bool _processingPayment = false;
  BilingualCopy? _error;

  @override
  void initState() {
    super.initState();
    final modes = widget.controller.profile?.paymentModes ?? const <String>[];
    for (final mode in modes) {
      _amounts[mode] = TextEditingController();
    }
    if (modes.isNotEmpty) {
      final defaultMode = modes.contains('Cash') ? 'Cash' : modes.first;
      _amounts[defaultMode]!.text = widget.order.roundedTotal.toStringAsFixed(
        2,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _enteredTotal => _amounts.values.fold(
    0,
    (sum, controller) => sum + (double.tryParse(controller.text) ?? 0),
  );

  Future<void> _submit() async {
    if (_enteredTotal + 0.005 < widget.order.roundedTotal) {
      setState(() => _error = _short);
      return;
    }
    final payments = _amounts.entries
        .map(
          (entry) => RestaurantPaymentLine(
            mode: entry.key,
            amount: double.tryParse(entry.value.text) ?? 0,
          ),
        )
        .where((line) => line.amount > 0)
        .toList(growable: false);
    setState(() {
      _processingPayment = true;
      _error = null;
    });
    final success = await widget.controller.pay(widget.order, payments);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    final caught = widget.controller.error;
    setState(() {
      _processingPayment = false;
      _error =
          caught is RestaurantRepositoryException &&
              caught.failure == RestaurantRepositoryFailure.posOpeningRequired
          ? _opening
          : _failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.controller.profile?.currency ?? '';
    return Scaffold(
      appBar: AppBar(title: const BilingualText(_title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(widget.order.name),
                        const SizedBox(height: 12),
                        const BilingualText(
                          _total,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '$currency ${widget.order.roundedTotal.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const BilingualText(_methods),
                const SizedBox(height: 10),
                if (_amounts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: BilingualText(_noModes),
                    ),
                  ),
                ..._amounts.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: entry.value,
                      enabled: !_processingPayment,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: entry.key,
                        suffixText: currency,
                      ),
                    ),
                  ),
                ),
                if (_amounts.isNotEmpty) ...[
                  Row(
                    children: [
                      const Expanded(child: BilingualText(_entered)),
                      Text(
                        '$currency ${_enteredTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    BilingualText(
                      _error!,
                      primaryStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      secondaryStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _processingPayment ? null : _submit,
                    icon: _processingPayment
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: BilingualText(
                      _processingPayment ? _processing : _pay,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
