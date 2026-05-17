import 'package:flutter/material.dart';

class OrderReceiptPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderReceiptPage({
    super.key,
    required this.order,
  });

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _shortId(dynamic value) {
    final id = value?.toString() ?? '';
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'N/A';
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }

  String _formatAddress(dynamic value) {
    if (value is! Map) return 'No delivery address linked';
    final parts = [
      value['house_number'],
      value['street'],
      value['barangay'],
      value['city'],
      value['province'],
      value['zip_code'],
    ]
        .map((part) => part?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'No delivery address linked' : parts.join(', ');
  }

  List<Map> _orderItems() {
    final items = order['order_items'];
    return items is List ? items.whereType<Map>().toList() : [];
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _orderItems();
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + _number(item['subtotal']),
    );
    final discount = _number(order['discount_amount']);
    final shipping = _number(order['shipping_fee']);
    final service = _number(order['service_fee']);
    final total = _number(order['total_amount']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Receipt #${_shortId(order['order_id'])}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_formatDate(order['order_date'])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Status', order['order_status']?.toString() ?? 'Processing'),
                  _row('Payment', order['payment_method']?.toString() ?? 'N/A'),
                  _row('Payment Status', order['payment_status']?.toString() ?? 'Pending'),
                  if ((order['discount_code']?.toString() ?? '').isNotEmpty)
                    _row('Coupon', order['discount_code'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_formatAddress(order['address'])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text('No items found')
                  else
                    ...items.map((item) {
                      final product = item['product'];
                      final variant = item['product_variant'];
                      final productName = product is Map
                          ? product['name']?.toString() ?? 'Product'
                          : 'Product';
                      final size = variant is Map
                          ? variant['size_label']?.toString() ?? ''
                          : '';
                      final quantity = int.tryParse(
                            item['quantity']?.toString() ?? '',
                          ) ??
                          1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${size.isEmpty ? 'Default size' : size} | Qty $quantity x ${_money(item['unit_price_at_sale'])}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _money(item['subtotal']),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Items Subtotal', _money(subtotal)),
                  _row('Delivery Fee', _money(shipping)),
                  _row('Service Fee', _money(service)),
                  if (discount > 0) _row('Discount', '-${_money(discount)}'),
                  const Divider(),
                  _row('Total Paid', _money(total), bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
