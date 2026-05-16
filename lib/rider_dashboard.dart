import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/notification_bell.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _logout() async {
    await AuthService.clearLoginSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'location':
        Navigator.pushNamed(context, '/addresses');
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  Future<void> _loadOrders() async {
    final orders = await DatabaseService.getAvailableDeliveryOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  String _formatAddress(dynamic value) {
    if (value is! Map) return 'No address';
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
    return parts.isEmpty ? 'No address' : parts.join(', ');
  }

  Future<void> _claimOrder(Map<String, dynamic> order) async {
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Pickup Code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Pickup code',
            prefixIcon: Icon(Icons.qr_code_scanner),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Pickup'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      codeController.dispose();
      return;
    }

    final ok = await DatabaseService.markOrderInTransitWithPickupCode(
      orderId: order['order_id'].toString(),
      pickupCode: codeController.text,
    );
    codeController.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Order is now in transit' : 'Invalid pickup code')),
    );
    if (ok) _loadOrders();
  }

  Future<void> _deliverOrder(Map<String, dynamic> order) async {
    final proofController = TextEditingController();
    XFile? proofImage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Proof of Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: proofController,
                decoration: const InputDecoration(
                  labelText: 'Seller call note / delivery note',
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 60,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (image != null) {
                      setDialogState(() => proofImage = image);
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    proofImage == null ? 'Add delivery photo' : proofImage!.name,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: proofImage == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Mark Delivered'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      proofController.dispose();
      return;
    }

    final proofPath = await DatabaseService.uploadDeliveryProof(
      orderId: order['order_id'].toString(),
      bytes: await proofImage!.readAsBytes(),
      fileName: proofImage!.name,
      contentType: proofImage!.mimeType,
    );
    if (proofPath == null) {
      proofController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery photo could not be uploaded')),
      );
      return;
    }

    final ok = await DatabaseService.markOrderDelivered(
      orderId: order['order_id'].toString(),
      proofOfDeliveryUrl: proofPath,
      proofNote: proofController.text,
    );
    proofController.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Delivery completed' : 'Delivery could not be completed')),
    );
    if (ok) _loadOrders();
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final buyer = order['account'];
    final buyerName = buyer is Map
        ? '${buyer['firstname'] ?? 'Buyer'} ${buyer['surname'] ?? ''}'.trim()
        : 'Buyer';
    final buyerPhone = buyer is Map ? buyer['phone_number']?.toString() ?? '' : '';
    final status = order['order_status']?.toString() ?? 'Ready for Pickup';
    final items = order['order_items'];
    final orderItems = items is List ? items.whereType<Map>().toList() : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    buyerName.isEmpty ? 'Buyer' : buyerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            if (buyerPhone.isNotEmpty) Text(buyerPhone),
            const SizedBox(height: 8),
            Text(_formatAddress(order['address'])),
            const Divider(),
            ...orderItems.map((item) {
              final product = item['product'];
              final variant = item['product_variant'];
              final productName = product is Map
                  ? product['name']?.toString() ?? 'Product'
                  : 'Product';
              final size = variant is Map
                  ? variant['size_label']?.toString() ?? ''
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item['quantity'] ?? 1}x $productName${size.isEmpty ? '' : ' ($size)'}',
                ),
              );
            }),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(order['rider_fee']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (status == 'Ready for Pickup')
                  FilledButton.icon(
                    onPressed: () => _claimOrder(order),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('Pick Up'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _deliverOrder(order),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Delivered'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Rider Dashboard'),
        backgroundColor: const Color(0xFF2d8f4e),
        actions: [
          const NotificationBell(),
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: _handleMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem(
                value: 'location',
                child: ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text('Delivery Location'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No deliveries ready')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) => _orderCard(_orders[index]),
                    ),
            ),
    );
  }
}
