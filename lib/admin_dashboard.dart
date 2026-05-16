import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/notification_bell.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _sellerApplications = [];
  List<Map<String, dynamic>> _riderApplications = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = false;

  double get _totalSales =>
      _orders.fold(0.0, (sum, order) => sum + _toDouble(order['total_amount']));
  int get _totalOrders => _orders.length;
  double get _avgOrderValue => _totalOrders == 0 ? 0 : _totalSales / _totalOrders;

  @override
  void initState() {
    super.initState();
    _loadAdminOrders();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final coupons = await DatabaseService.getCoupons();
    if (!mounted) return;
    setState(() => _coupons = coupons);
  }

  Future<void> _loadAdminOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await DatabaseService.getAdminOrders();
      if (mounted) {
        setState(() => _orders = orders);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSellerApplications() async {
    setState(() => _isLoading = true);
    try {
      final applications = await DatabaseService.getSellerApplications();
      if (mounted) {
        setState(() => _sellerApplications = applications);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRiderApplications() async {
    setState(() => _isLoading = true);
    try {
      final applications = await DatabaseService.getRiderApplications();
      if (mounted) {
        setState(() => _riderApplications = applications);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveSeller(Map<String, dynamic> app) async {
    try {
      final approved = await DatabaseService.approveSellerApplication(
        applicationId: app['application_id'].toString(),
        accountId: app['account_id'].toString(),
        storeName: app['store_name']?.toString() ?? 'Store',
        storeDescription: app['store_description']?.toString(),
        province: app['province']?.toString(),
        city: app['city']?.toString() ?? '',
        barangay: app['barangay']?.toString(),
        street: app['street']?.toString(),
        houseNumber: app['house_number']?.toString(),
        zipCode: app['zip_code']?.toString(),
        contactPhone: app['contact_phone']?.toString(),
      );

      if (!approved) {
        throw Exception('Seller application could not be approved');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller application approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSellerApplications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _rejectSeller(Map<String, dynamic> app) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseService.rejectSellerApplication(
                  applicationId: app['application_id'],
                  reviewNotes: notesController.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pop(context);
                  _loadSellerApplications();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRider(Map<String, dynamic> app) async {
    try {
      final approved = await DatabaseService.approveRiderApplication(
        applicationId: app['rider_app_id'].toString(),
        accountId: app['account_id'].toString(),
      );

      if (!approved) {
        throw Exception('Rider application could not be approved');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rider application approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRiderApplications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _rejectRider(Map<String, dynamic> app) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Rider Application'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.rejectRiderApplication(
                applicationId: app['rider_app_id'],
                reviewNotes: notesController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rider application rejected'),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pop(context);
                _loadRiderApplications();
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _viewApplicationDetails(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app['store_name'] ?? 'Application'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'Applicant',
                  '${app['account']?['firstname'] ?? 'N/A'} ${app['account']?['surname'] ?? ''}',
                ),
                _detailRow('Email', app['account']?['email'] ?? 'N/A'),
                _detailRow('Store Name', app['store_name'] ?? 'N/A'),
                _detailRow('Phone', app['contact_phone'] ?? 'N/A'),
                _detailRow('Business Address', _formatSellerAddress(app)),
                _detailRow('Province', app['province'] ?? 'N/A'),
                _detailRow('Municipality/City', app['city'] ?? 'N/A'),
                _detailRow('Barangay', app['barangay'] ?? 'N/A'),
                _detailRow('Street', app['street'] ?? 'N/A'),
                _detailRow('House Number', app['house_number'] ?? 'N/A'),
                _detailRow('Zip Code', app['zip_code'] ?? 'N/A'),
                _detailRow('Status', app['status'] ?? 'N/A'),
                _detailRow('Submitted', app['submission_date'] ?? 'N/A'),
                _documentsSection(app['documents_path']),
                if (app['store_description'] != null &&
                    app['store_description'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(app['store_description']),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (app['status'] == 'Pending Review') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectSeller(app);
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _approveSeller(app);
              },
              child: const Text(
                'Approve',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewRiderApplicationDetails(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app['account']?['firstname'] ?? 'Rider Application'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'Applicant',
                  '${app['account']?['firstname'] ?? 'N/A'} ${app['account']?['surname'] ?? ''}',
                ),
                _detailRow('Email', app['account']?['email'] ?? 'N/A'),
                _detailRow('Phone', app['account']?['phone_number'] ?? 'N/A'),
                _detailRow('License Number', app['license_number'] ?? 'N/A'),
                _detailRow('Vehicle Type', app['vehicle_type'] ?? 'N/A'),
                _detailRow('Plate Number', app['plate_number'] ?? 'N/A'),
                _detailRow('Rider Address', _formatSellerAddress(app)),
                _detailRow('Status', app['status'] ?? 'N/A'),
                _detailRow('Submitted', app['application_date'] ?? 'N/A'),
                _documentsSection(app['documents_path']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (app['status'] == 'Pending Review') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRider(app);
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _approveRider(app);
              },
              child: const Text(
                'Approve',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSellerAddress(Map<String, dynamic> app) {
    final parts =
        [
              app['house_number'],
              app['street'],
      app['barangay'],
      app['city'],
      app['province'],
      app['zip_code'],
    ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    if (parts.isNotEmpty) return parts.join(', ');

    return app['business_address']?.toString() ?? 'N/A';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _documentsSection(dynamic value) {
    final documents = _documentsFromPath(value);
    if (documents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 8),
        child: Text('Documents: none uploaded'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Documents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...documents.map((document) {
          final fileName = document['file_name']?.toString() ?? 'Document';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _isImageDocument(document)
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
            ),
            title: Text(fileName),
            subtitle: Text(document['label']?.toString() ?? ''),
            trailing: OutlinedButton.icon(
              onPressed: () => _showDocument(document),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Show'),
            ),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _documentsFromPath(dynamic value) {
    if (value is Map) {
      final files = value['files'];
      if (files is List) {
        return files
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return [];
  }

  bool _isImageDocument(Map<String, dynamic> document) {
    return (document['content_type']?.toString() ?? '').startsWith('image/');
  }

  Future<void> _showDocument(Map<String, dynamic> document) async {
    final bucket = document['bucket']?.toString() ?? 'application-documents';
    final path = document['path']?.toString();
    if (path == null || path.isEmpty) return;

    final url = await DatabaseService.createSignedStorageUrl(
      bucket: bucket,
      path: path,
    );
    if (!mounted || url == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document['file_name']?.toString() ?? 'Document'),
        content: SizedBox(
          width: 720,
          child: _isImageDocument(document)
              ? Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SelectableText(url),
                )
              : SelectableText(url),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerApplicationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sellerApplications.isEmpty) {
      return const Center(child: Text('No seller applications'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sellerApplications.length,
      itemBuilder: (context, index) {
        final app = _sellerApplications[index];
        final statusColor = app['status'] == 'Approved'
            ? Colors.green
            : app['status'] == 'Rejected'
            ? Colors.red
            : Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(app['store_name'] ?? 'Store'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${app['account']?['firstname'] ?? 'Unknown'} ${app['account']?['surname'] ?? ''}',
                ),
                Text(app['contact_phone'] ?? ''),
                Chip(
                  label: Text(app['status'] ?? 'Pending'),
                  backgroundColor: statusColor.withOpacity(0.3),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _viewApplicationDetails(app),
            ),
            onTap: () => _viewApplicationDetails(app),
          ),
        );
      },
    );
  }

  Widget _buildRiderApplicationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_riderApplications.isEmpty) {
      return const Center(child: Text('No rider applications'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _riderApplications.length,
      itemBuilder: (context, index) {
        final app = _riderApplications[index];
        final statusColor = app['status'] == 'Approved'
            ? Colors.green
            : app['status'] == 'Rejected'
            ? Colors.red
            : Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              '${app['account']?['firstname'] ?? 'Unknown'} ${app['account']?['surname'] ?? ''}',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['vehicle_type'] ?? ''),
                Text(app['plate_number'] ?? ''),
                Chip(
                  label: Text(app['status'] ?? 'Pending'),
                  backgroundColor: statusColor.withOpacity(0.3),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _viewRiderApplicationDetails(app),
            ),
            onTap: () => _viewRiderApplicationDetails(app),
          ),
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _heroSection(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _metricCard(
                    'Total Sales',
                    '₱${_totalSales.toStringAsFixed(0)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    'Total Orders',
                    '$_totalOrders',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _metricCard(
              'Avg Order Value',
              '₱${_avgOrderValue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Daily Revenue'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) => _revenueBar(_dailySales()[i], i)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSalesReportTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Total')),
          ],
          rows: _orders.map((order) {
            final orderId = order['order_id']?.toString() ?? '';
            return DataRow(
              onSelectChanged: (_) => _showOrderDetails(order),
              cells: [
                DataCell(Text(_shortId(orderId))),
                DataCell(Text(_customerName(order))),
                DataCell(Text(_formatDate(order['order_date']))),
                DataCell(Text(_itemCount(order).toString())),
                DataCell(Text(order['order_status']?.toString() ?? 'N/A')),
                DataCell(
                  Text('₱${_toDouble(order['total_amount']).toStringAsFixed(2)}'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openCouponForm([Map<String, dynamic>? coupon]) async {
    final codeController =
        TextEditingController(text: coupon?['code']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: coupon?['description']?.toString() ?? '',
    );
    final valueController = TextEditingController(
      text: coupon?['discount_value']?.toString() ?? '',
    );
    final minController = TextEditingController(
      text: coupon?['min_subtotal']?.toString() ?? '0',
    );
    final expiryController = TextEditingController(
      text: coupon?['expires_at']?.toString() ?? '',
    );
    var type = coupon?['discount_type']?.toString() ?? 'percent';
    var active = coupon?['is_active'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(coupon == null ? 'Add Coupon' : 'Edit Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Percent')),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount Value'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum Subtotal'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Expires At',
                    hintText: '2026-12-31T23:59:59Z',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  value: active,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  onChanged: (value) => setDialogState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final ok = await DatabaseService.saveCoupon(
        code: codeController.text,
        discountType: type,
        discountValue: double.tryParse(valueController.text.trim()) ?? 0,
        minSubtotal: double.tryParse(minController.text.trim()) ?? 0,
        description: descriptionController.text,
        expiresAt: expiryController.text,
        isActive: active,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Coupon saved' : 'Coupon could not be saved')),
        );
      }
      if (ok) _loadCoupons();
    }

    codeController.dispose();
    descriptionController.dispose();
    valueController.dispose();
    minController.dispose();
    expiryController.dispose();
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _openCouponForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Coupon'),
            ),
          ),
          const SizedBox(height: 12),
          if (_coupons.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No coupons yet')),
            )
          else
            ..._coupons.map((coupon) {
              final type = coupon['discount_type']?.toString() == 'amount'
                  ? 'PHP ${coupon['discount_value']} off'
                  : '${coupon['discount_value']}% off';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text(coupon['code']?.toString() ?? 'COUPON'),
                  subtitle: Text(
                    '$type | Used ${coupon['times_used'] ?? 0} time(s)',
                  ),
                  trailing: Switch(
                    value: coupon['is_active'] != false,
                    onChanged: (value) async {
                      await DatabaseService.saveCoupon(
                        code: coupon['code'].toString(),
                        discountType:
                            coupon['discount_type']?.toString() ?? 'percent',
                        discountValue: _toDouble(coupon['discount_value']),
                        minSubtotal: _toDouble(coupon['min_subtotal']),
                        description: coupon['description']?.toString(),
                        expiresAt: coupon['expires_at']?.toString(),
                        isActive: value,
                      );
                      _loadCoupons();
                    },
                  ),
                  onTap: () => _openCouponForm(coupon),
                ),
              );
            }),
        ],
      ),
    );
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
      case 'logout':
        _logout();
        break;
    }
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueBar(double value, int index) {
    return Column(
      children: [
        Container(
          width: 40,
          height: (value / 4000 * 150).clamp(20, 150),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text('₱${value.toStringAsFixed(0)}'),
        Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][index]),
      ],
    );
  }

  List<double> _dailySales() {
    final sales = List<double>.filled(5, 0);
    final today = DateTime.now();

    for (final order in _orders) {
      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (date == null) continue;

      final daysAgo = DateTime(today.year, today.month, today.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;

      if (daysAgo >= 0 && daysAgo < 5) {
        sales[4 - daysAgo] += _toDouble(order['total_amount']);
      }
    }

    return sales;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _itemCount(Map<String, dynamic> order) {
    final items = order['order_items'];
    if (items is! List) return 0;

    return items.fold<int>(0, (sum, item) {
      if (item is! Map) return sum;
      final quantity = item['quantity'];
      if (quantity is int) return sum + quantity;
      return sum + (int.tryParse(quantity?.toString() ?? '') ?? 0);
    });
  }

  String _customerName(Map<String, dynamic> order) {
    final account = order['account'];
    if (account is! Map) return 'Unknown';

    final firstName = account['firstname']?.toString() ?? '';
    final surname = account['surname']?.toString() ?? '';
    final name = '$firstName $surname'.trim();
    return name.isEmpty ? account['email']?.toString() ?? 'Unknown' : name;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '#${id.substring(0, 8)}';
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${_shortId(order['order_id']?.toString() ?? '')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_customerName(order)}'),
            Text('Date: ${_formatDate(order['order_date'])}'),
            Text('Items: ${_itemCount(order)}'),
            Text('Status: ${order['order_status'] ?? 'N/A'}'),
            Text('Payment: ${order['payment_method'] ?? 'N/A'}'),
            Text(
              'Total: ₱${_toDouble(order['total_amount']).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _heroSection() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2d8f4e),
            const Color(0xFF2d8f4e).withOpacity(0.85),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset('assets/images/pizza.jpg', fit: BoxFit.cover),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your FoodTaxi business',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildDashboardTab(),
      _buildSalesReportTab(),
      _buildSellerApplicationsTab(),
      _buildRiderApplicationsTab(),
      _buildCouponsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF2d8f4e),
        elevation: 0,
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              if (_currentIndex == 2) {
                _loadSellerApplications();
              } else if (_currentIndex == 3) {
                _loadRiderApplications();
              } else if (_currentIndex == 4) {
                _loadCoupons();
              } else {
                _loadAdminOrders();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
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
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            _loadSellerApplications();
          } else if (index == 3) {
            _loadRiderApplications();
          } else if (index == 4) {
            _loadCoupons();
          } else if (index == 0 || index == 1) {
            _loadAdminOrders();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Sellers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Riders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer),
            label: 'Coupons',
          ),
        ],
      ),
    );
  }
}
