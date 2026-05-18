import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/adaptive_menu_item.dart';
import 'widgets/notification_bell.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _readyOrdersChannel;
  RealtimeChannel? _assignedOrdersChannel;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  Map<String, dynamic>? _account;
  bool _isLoading = true;
  int _currentIndex = 0;
  String _overviewRange = 'Day';

  static const List<String> _overviewRanges = ['Day', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    final readyOrdersChannel = _readyOrdersChannel;
    final assignedOrdersChannel = _assignedOrdersChannel;
    if (readyOrdersChannel != null) _supabase.removeChannel(readyOrdersChannel);
    if (assignedOrdersChannel != null) {
      _supabase.removeChannel(assignedOrdersChannel);
    }
    super.dispose();
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
    final account = await DatabaseService.getCurrentAccount();
    final orders = await DatabaseService.getAvailableDeliveryOrders();
    final historyOrders = await DatabaseService.getCurrentRiderOrders();
    if (!mounted) return;
    setState(() {
      _account = account;
      _orders = orders;
      _historyOrders = historyOrders;
      _isLoading = false;
    });
    _subscribeToOrders(account?['account_id']?.toString());
  }

  void _subscribeToOrders(String? accountId) {
    _readyOrdersChannel ??= _supabase
          .channel('rider-ready-orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_status',
              value: 'Ready for Pickup',
            ),
            callback: (_) => _loadOrders(),
          )
          .subscribe();

    if (accountId != null && _assignedOrdersChannel == null) {
      _assignedOrdersChannel = _supabase
          .channel('rider-assigned-orders-$accountId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'rider_account_id',
              value: accountId,
            ),
            callback: (_) => _loadOrders(),
          )
          .subscribe();
    }
  }

  Widget _profileMenuHeader() {
    final account = _account;
    if (account == null) return const Text('Profile');
    final imageUrl = account['profile_image_url']?.toString() ?? '';
    final first = account['firstname']?.toString() ?? '';
    final last = account['surname']?.toString() ?? '';
    final name = '$first $last'.trim();
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: imageUrl.isNotEmpty
                ? NetworkImage(DatabaseService.getProfileImageUrl(imageUrl))
                : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Rider' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  account['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _status(Map<String, dynamic> order) {
    return order['order_status']?.toString() ?? 'Ready for Pickup';
  }

  bool _isDelivered(Map<String, dynamic> order) {
    return _status(order).toLowerCase() == 'delivered';
  }

  Map<dynamic, dynamic>? _buyerFor(Map<String, dynamic> order) {
    final account = order['account'];
    return account is Map ? account : null;
  }

  String _buyerName(Map<String, dynamic> order) {
    final buyer = _buyerFor(order);
    final first = buyer?['firstname']?.toString().trim() ?? '';
    final last = buyer?['surname']?.toString().trim() ?? '';
    final name = '$first $last'.trim();
    if (name.isNotEmpty) return name;
    final email = buyer?['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    final phone = buyer?['phone_number']?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;
    final buyerId = order['buyer_account_id']?.toString() ?? '';
    if (buyerId.length >= 8) return 'Buyer ${buyerId.substring(0, 8)}';
    return 'Unknown Buyer';
  }

  String _buyerPhone(Map<String, dynamic> order) {
    return _buyerFor(order)?['phone_number']?.toString().trim() ?? '';
  }

  DateTime? _orderDate(Map<String, dynamic> order, {bool preferDelivered = false}) {
    final value = preferDelivered
        ? order['delivered_at'] ?? order['order_date']
        : order['order_date'];
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _shortDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _periodKey(DateTime date, String range) {
    if (range == 'Year') return '${date.year}';
    if (range == 'Month') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
    if (range == 'Week') {
      final start = DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));
      return 'Week of ${_shortDate(start)}';
    }
    return _shortDate(date);
  }

  List<Map<String, dynamic>> _periodStats({
    required Iterable<Map<String, dynamic>> orders,
    required String range,
    bool deliveredOnly = true,
  }) {
    final stats = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      if (deliveredOnly && !_isDelivered(order)) continue;
      final date = _orderDate(order, preferDelivered: deliveredOnly);
      if (date == null) continue;
      final key = _periodKey(date, range);
      final row = stats.putIfAbsent(
        key,
        () => {
          'period': key,
          'deliveries': 0,
          'earnings': 0.0,
          'distance': 0.0,
          'date': date,
        },
      );
      row['deliveries'] = (row['deliveries'] as int) + 1;
      row['earnings'] = (row['earnings'] as double) +
          _number(order['rider_fee'] ?? order['shipping_fee']);
      row['distance'] = (row['distance'] as double) +
          _number(order['delivery_distance_km']);
      final currentDate = row['date'] as DateTime;
      if (date.isAfter(currentDate)) row['date'] = date;
    }

    final rows = stats.values.toList()
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return rows.take(8).toList();
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
    final buyerName = _buyerName(order);
    final buyerPhone = _buyerPhone(order);
    final status = _status(order);
    final items = order['order_items'];
    final orderItems = items is List ? items.whereType<Map>().toList() : [];
    final riderFee = order['rider_fee'] ?? order['shipping_fee'];
    final distance = double.tryParse(
      order['delivery_distance_km']?.toString() ?? '',
    );

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
                    buyerName,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order total: ${_money(order['total_amount'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        distance == null
                            ? 'Delivery fee: ${_money(riderFee)}'
                            : 'Delivery fee: ${_money(riderFee)} (${distance.toStringAsFixed(1)} km)',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (status == 'Ready for Pickup')
                  FilledButton.icon(
                    onPressed: () => _claimOrder(order),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('Pick Up'),
                  )
                else if (status == 'In Transit')
                  FilledButton.icon(
                    onPressed: () => _deliverOrder(order),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Delivered'),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.verified_outlined, size: 18),
                    label: Text('Completed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Wrap(
      spacing: 8,
      children: _overviewRanges
          .map(
            (range) => ChoiceChip(
              label: Text(range),
              selected: _overviewRange == range,
              onSelected: (_) => setState(() => _overviewRange = range),
            ),
          )
          .toList(),
    );
  }

  Widget _buildOverviewTab() {
    final deliveredOrders = _historyOrders.where(_isDelivered).toList();
    final inTransitOrders =
        _orders.where((order) => _status(order) == 'In Transit').toList();
    final readyOrders =
        _orders.where((order) => _status(order) == 'Ready for Pickup').toList();
    final earnings = deliveredOrders.fold<double>(
      0,
      (sum, order) => sum + _number(order['rider_fee'] ?? order['shipping_fee']),
    );
    final periodRows = _periodStats(
      orders: _historyOrders,
      range: _overviewRange,
    );
    final nearestReady = readyOrders.isEmpty ? null : readyOrders.first;
    final nextActionText = inTransitOrders.isNotEmpty
        ? 'Finish ${inTransitOrders.length} active delivery${inTransitOrders.length == 1 ? '' : 'ies'}.'
        : readyOrders.isNotEmpty
            ? 'There ${readyOrders.length == 1 ? 'is' : 'are'} ${readyOrders.length} order${readyOrders.length == 1 ? '' : 's'} ready for pickup.'
            : 'No pickup jobs are ready right now.';

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Rider Overview',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Delivery queue, completed work, and earnings history',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricCard(
                'Delivered',
                '${deliveredOrders.length}',
                Icons.verified_outlined,
                Colors.green,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Earnings',
                _money(earnings),
                Icons.payments_outlined,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCard(
                'Ready',
                '${readyOrders.length}',
                Icons.inventory_2_outlined,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'In Transit',
                '${inTransitOrders.length}',
                Icons.delivery_dining,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next Ride',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(nextActionText),
                  if (nearestReady != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatAddress(nearestReady['address']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _currentIndex = 1),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Open Queue'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _currentIndex = 2),
                          icon: const Icon(Icons.history_outlined),
                          label: const Text('History'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Delivery History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          _periodSelector(),
          const SizedBox(height: 10),
          if (periodRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No completed deliveries yet')),
            )
          else
            ...periodRows.map(
              (row) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.route_outlined),
                  ),
                  title: Text(row['period'].toString()),
                  subtitle: Text(
                    '${row['deliveries']} deliver${row['deliveries'] == 1 ? 'y' : 'ies'} | ${(row['distance'] as double).toStringAsFixed(1)} km',
                  ),
                  trailing: Text(
                    _money(row['earnings']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return RefreshIndicator(
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
    );
  }

  Widget _buildHistoryTab() {
    final history = _historyOrders;
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: history.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('No delivery history yet')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) => _orderCard(history[index]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Rider Dashboard'),
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
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: _profileMenuHeader(),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'profile',
                child: const AdaptiveMenuItem(icon: Icons.person, title: 'Profile'),
              ),
              PopupMenuItem(
                value: 'location',
                child: const AdaptiveMenuItem(
                  icon: Icons.location_on,
                  title: 'Delivery Location',
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: const AdaptiveMenuItem(icon: Icons.settings, title: 'Settings'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: const AdaptiveMenuItem(icon: Icons.logout, title: 'Logout'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
              ? _buildOverviewTab()
              : _currentIndex == 1
                  ? _buildDeliveriesTab()
                  : _buildHistoryTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
