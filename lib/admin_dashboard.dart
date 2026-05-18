import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/adaptive_menu_item.dart';
import 'widgets/notification_bell.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _CommissionLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _CommissionLinePainter({
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final denominator = maxValue <= 0 ? 1 : maxValue;
    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = <Offset>[];

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1 ? size.width / 2 : step * index;
      final y = size.height - ((values[index] / denominator) * size.height);
      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CommissionLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _sellerApplications = [];
  List<Map<String, dynamic>> _riderApplications = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _storeReports = [];
  List<Map<String, dynamic>> _productReports = [];
  Map<String, dynamic>? _account;
  bool _isLoading = false;
  final _salesSearchController = TextEditingController();
  final _reportSearchController = TextEditingController();
  String _salesStatusFilter = 'All';
  String _salesDateFilter = 'All';
  String _commissionRange = 'Days';
  String _sellerApplicationFilter = 'Pending Review';
  String _riderApplicationFilter = 'Pending Review';
  String _reportTypeFilter = 'All';

  static const List<String> _orderStatusFilters = [
    'All',
    'Processing',
    'Ready for Pickup',
    'In Transit',
    'Delivered',
    'Cancelled',
  ];
  static const List<String> _applicationStatusFilters = [
    'Pending Review',
    'Approved',
    'Rejected',
    'All',
  ];
  static const List<String> _salesDateFilters = [
    'All',
    'Today',
    '7 Days',
    '30 Days',
  ];
  static const List<String> _commissionRanges = ['Days', 'Weeks', 'Months'];
  static const List<String> _reportTypeFilters = [
    'All',
    'Store',
    'Product',
  ];

  List<Map<String, dynamic>> get _successfulOrders => _orders
      .where((order) {
        final status = order['order_status']?.toString().toLowerCase() ?? '';
        return status != 'cancelled' && status != 'canceled';
      })
      .toList();

  double get _totalCommission => _successfulOrders.fold(
        0.0,
        (sum, order) => sum + _toDouble(order['admin_commission']),
      );
  int get _totalOrders => _successfulOrders.length;
  double get _avgCommission =>
      _totalOrders == 0 ? 0 : _totalCommission / _totalOrders;

  List<Map<String, dynamic>> get _filteredSalesOrders {
    final query = _salesSearchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return _orders.where((order) {
      final status = order['order_status']?.toString() ?? 'Processing';
      if (_salesStatusFilter != 'All' && status != _salesStatusFilter) {
        return false;
      }

      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (_salesDateFilter != 'All') {
        if (date == null) return false;
        final days = DateTime(now.year, now.month, now.day)
            .difference(DateTime(date.year, date.month, date.day))
            .inDays;
        if (_salesDateFilter == 'Today' && days != 0) return false;
        if (_salesDateFilter == '7 Days' && (days < 0 || days > 6)) {
          return false;
        }
        if (_salesDateFilter == '30 Days' && (days < 0 || days > 29)) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      final buyer = order['account'];
      final buyerText = buyer is Map
          ? '${buyer['firstname'] ?? ''} ${buyer['surname'] ?? ''} ${buyer['email'] ?? ''}'
          : '';
      final haystack = [
        order['order_id'],
        order['buyer_account_id'],
        order['seller_account_id'],
        buyerText,
        status,
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _salesSearchController.dispose();
    _reportSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAdminOrders();
    _loadCoupons();
    _loadReports();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final account = await DatabaseService.getCurrentAccount();
    if (!mounted) return;
    setState(() => _account = account);
  }

  Future<void> _loadCoupons() async {
    final coupons = await DatabaseService.getCoupons();
    if (!mounted) return;
    setState(() => _coupons = coupons);
  }

  Future<void> _loadReports() async {
    final storeReports = await DatabaseService.getAdminStoreReports();
    final productReports = await DatabaseService.getAdminProductReports();
    if (!mounted) return;
    setState(() {
      _storeReports = storeReports;
      _productReports = productReports;
    });
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

  void _approveSeller(Map<String, dynamic> app) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes for applicant',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
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
                reviewNotes: notesController.text,
              );
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approved
                        ? 'Seller application approved'
                        : 'Seller application could not be approved',
                  ),
                  backgroundColor: approved ? Colors.green : Colors.red,
                ),
              );
              if (approved) _loadSellerApplications();
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
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
                if (context.mounted && mounted) {
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
                if (context.mounted && mounted) {
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

  void _approveRider(Map<String, dynamic> app) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Rider Application'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes for applicant',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final approved = await DatabaseService.approveRiderApplication(
                applicationId: app['rider_app_id'].toString(),
                accountId: app['account_id'].toString(),
                reviewNotes: notesController.text,
              );
              if (!context.mounted || !mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approved
                        ? 'Rider application approved'
                        : 'Rider application could not be approved',
                  ),
                  backgroundColor: approved ? Colors.green : Colors.red,
                ),
              );
              if (approved) _loadRiderApplications();
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
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
              if (context.mounted && mounted) {
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
                if ((app['review_notes']?.toString().trim().isNotEmpty ?? false))
                  _detailRow('Admin Notes', app['review_notes'].toString()),
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
                if ((app['review_notes']?.toString().trim().isNotEmpty ?? false))
                  _detailRow('Admin Notes', app['review_notes'].toString()),
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

    final visible = _filteredApplications(
      _sellerApplications,
      _sellerApplicationFilter,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.isEmpty ? 2 : visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _filterChips(
              values: _applicationStatusFilters,
              selected: _sellerApplicationFilter,
              onSelected: (value) =>
                  setState(() => _sellerApplicationFilter = value),
            ),
          );
        }
        if (visible.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: Text('No seller applications in this state')),
          );
        }

        final app = visible[index - 1];
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
                  backgroundColor: statusColor.withAlpha(77),
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

    final visible = _filteredApplications(
      _riderApplications,
      _riderApplicationFilter,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.isEmpty ? 2 : visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _filterChips(
              values: _applicationStatusFilters,
              selected: _riderApplicationFilter,
              onSelected: (value) =>
                  setState(() => _riderApplicationFilter = value),
            ),
          );
        }
        if (visible.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: Text('No rider applications in this state')),
          );
        }

        final app = visible[index - 1];
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
                  backgroundColor: statusColor.withAlpha(77),
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

  List<Map<String, dynamic>> _filteredApplications(
    List<Map<String, dynamic>> applications,
    String status,
  ) {
    if (status == 'All') return applications;
    return applications
        .where((app) => app['status']?.toString() == status)
        .toList();
  }

  Widget _filterChips({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values
            .map(
              (value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
              ),
            )
            .toList(),
      ),
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
                    'Admin Commission',
                    '₱${_totalCommission.toStringAsFixed(0)}',
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
              'Avg Commission',
              '₱${_avgCommission.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Commission Sales'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: _commissionRanges
                      .map(
                        (range) => ChoiceChip(
                          label: Text(range),
                          selected: _commissionRange == range,
                          onSelected: (_) =>
                              setState(() => _commissionRange = range),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                _commissionLineChart(_commissionSeries()),
              ],
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

    final visible = _filteredSalesOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _salesSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search order, buyer, account id, or status',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _filterChips(
            values: _orderStatusFilters,
            selected: _salesStatusFilter,
            onSelected: (value) => setState(() => _salesStatusFilter = value),
          ),
          const SizedBox(height: 8),
          _filterChips(
            values: _salesDateFilters,
            selected: _salesDateFilter,
            onSelected: (value) => setState(() => _salesDateFilter = value),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No orders match these filters')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
          columns: const [
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Buyer Account')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Commission')),
          ],
          rows: visible.map((order) {
            final orderId = order['order_id']?.toString() ?? '';
            return DataRow(
              onSelectChanged: (_) => _showOrderDetails(order),
              cells: [
                DataCell(Text(_shortId(orderId))),
                DataCell(Text(_shortId(order['buyer_account_id']?.toString() ?? ''))),
                DataCell(Text(_customerName(order))),
                DataCell(Text(_formatDate(order['order_date']))),
                DataCell(Text(_itemCount(order).toString())),
                DataCell(Text(order['order_status']?.toString() ?? 'N/A')),
                DataCell(
                  Text('₱${_toDouble(order['admin_commission']).toStringAsFixed(2)}'),
                ),
              ],
            );
          }).toList(),
              ),
            ),
        ],
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
                  initialValue: type,
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

  List<Map<String, dynamic>> get _filteredReports {
    final query = _reportSearchController.text.trim().toLowerCase();
    final reports = <Map<String, dynamic>>[
      ..._storeReports.map((report) => {'type': 'Store', 'data': report}),
      ..._productReports.map((report) => {'type': 'Product', 'data': report}),
    ];

    return reports.where((entry) {
      final type = entry['type']?.toString() ?? '';
      if (_reportTypeFilter != 'All' && type != _reportTypeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final report = entry['data'];
      if (report is! Map) return false;
      final store = report['store'];
      final product = report['product'];
      final reporter = report['account'];
      final reporterText = reporter is Map
          ? '${reporter['firstname'] ?? ''} ${reporter['surname'] ?? ''} ${reporter['email'] ?? ''}'
          : '';
      final haystack = [
        type,
        report['reason'],
        report['details'],
        report['status'],
        report['store_id'],
        report['product_id'],
        store is Map ? store['store_name'] : '',
        product is Map ? product['name'] : '',
        reporterText,
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList()
      ..sort((a, b) {
        final aData = a['data'];
        final bData = b['data'];
        final aDate = aData is Map ? aData['created_at']?.toString() ?? '' : '';
        final bDate = bData is Map ? bData['created_at']?.toString() ?? '' : '';
        return bDate.compareTo(aDate);
      });
  }

  String _reportTarget(Map<String, dynamic> entry) {
    final type = entry['type']?.toString() ?? '';
    final report = entry['data'];
    if (report is! Map) return 'Unknown';
    if (type == 'Product') {
      final product = report['product'];
      if (product is Map) return product['name']?.toString() ?? 'Product';
      return report['product_id']?.toString() ?? 'Product';
    }
    final store = report['store'];
    if (store is Map) return store['store_name']?.toString() ?? 'Store';
    return report['store_id']?.toString() ?? 'Store';
  }

  String _reporterName(Map<String, dynamic> report) {
    final account = report['account'];
    if (account is! Map) return 'Unknown reporter';
    final first = account['firstname']?.toString() ?? '';
    final last = account['surname']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? account['email']?.toString() ?? 'Unknown reporter' : name;
  }

  Widget _buildReportsTab() {
    final reports = _filteredReports;
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _reportSearchController,
            decoration: const InputDecoration(
              labelText: 'Search reports',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _reportTypeFilters.map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: _reportTypeFilter == filter,
                onSelected: (_) => setState(() => _reportTypeFilter = filter),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No reports found')),
            )
          else
            ...reports.map((entry) {
              final type = entry['type']?.toString() ?? 'Report';
              final report = entry['data'];
              if (report is! Map<String, dynamic>) {
                return const SizedBox.shrink();
              }
              return Card(
                child: ListTile(
                  leading: Icon(
                    type == 'Product'
                        ? Icons.inventory_2_outlined
                        : Icons.storefront_outlined,
                  ),
                  title: Text('$type: ${_reportTarget(entry)}'),
                  subtitle: Text(
                    [
                      'Reason: ${report['reason'] ?? 'N/A'}',
                      'Reporter: ${_reporterName(report)}',
                      'Status: ${report['status'] ?? 'Pending'}',
                      'Date: ${_formatDate(report['created_at'])}',
                      if ((report['details']?.toString().trim() ?? '').isNotEmpty)
                        'Details: ${report['details']}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
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
            color: Colors.black.withAlpha(26),
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

  // ignore: unused_element
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
        Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index]),
      ],
    );
  }

  // ignore: unused_element
  List<double> _dailySales() {
    final sales = List<double>.filled(7, 0);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOfWeek = todayOnly.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    for (final order in _orders) {
      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (date == null) continue;
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isBefore(startOfWeek) || !dateOnly.isBefore(endOfWeek)) {
        continue;
      }

      final status = order['order_status']?.toString().toLowerCase() ?? '';
      if (status == 'cancelled' || status == 'canceled') continue;
      sales[dateOnly.weekday - 1] += _toDouble(order['admin_commission']);
    }

    return sales;
  }

  List<Map<String, dynamic>> _commissionSeries() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final buckets = <Map<String, dynamic>>[];

    if (_commissionRange == 'Weeks') {
      for (var index = 3; index >= 0; index--) {
        final day = todayOnly.subtract(Duration(days: index * 7));
        final start = day.subtract(Duration(days: day.weekday - 1));
        buckets.add({
          'start': start,
          'end': start.add(const Duration(days: 7)),
          'label': index == 0 ? 'This wk' : '-${index}w',
          'value': 0.0,
        });
      }
    } else if (_commissionRange == 'Months') {
      for (var index = 5; index >= 0; index--) {
        final start = DateTime(today.year, today.month - index, 1);
        buckets.add({
          'start': start,
          'end': DateTime(start.year, start.month + 1, 1),
          'label': '${start.month}/${start.year.toString().substring(2)}',
          'value': 0.0,
        });
      }
    } else {
      for (var index = 6; index >= 0; index--) {
        final start = todayOnly.subtract(Duration(days: index));
        buckets.add({
          'start': start,
          'end': start.add(const Duration(days: 1)),
          'label': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              [start.weekday - 1],
          'value': 0.0,
        });
      }
    }

    for (final order in _orders) {
      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (date == null) continue;
      final dateOnly = DateTime(date.year, date.month, date.day);
      final status = order['order_status']?.toString().toLowerCase() ?? '';
      if (status == 'cancelled' || status == 'canceled') continue;

      for (final bucket in buckets) {
        final start = bucket['start'] as DateTime;
        final end = bucket['end'] as DateTime;
        if (!dateOnly.isBefore(start) && dateOnly.isBefore(end)) {
          bucket['value'] =
              _toDouble(bucket['value']) + _toDouble(order['admin_commission']);
          break;
        }
      }
    }

    return buckets;
  }

  Widget _commissionLineChart(List<Map<String, dynamic>> rows) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _CommissionLinePainter(
                values: rows.map((row) => _toDouble(row['value'])).toList(),
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rows
                .map(
                  (row) => Expanded(
                    child: Text(
                      row['label'].toString(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
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
              'Commission: ₱${_toDouble(order['admin_commission']).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Order total: ₱${_toDouble(order['total_amount']).toStringAsFixed(2)}'),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary,
            scheme.primary.withAlpha(217),
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
                  name.isEmpty ? 'Admin' : name,
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildDashboardTab(),
      _buildSalesReportTab(),
      _buildSellerApplicationsTab(),
      _buildRiderApplicationsTab(),
      _buildCouponsTab(),
      _buildReportsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Panel'),
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
              } else if (_currentIndex == 5) {
                _loadReports();
              } else {
                _loadAdminOrders();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
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
          } else if (index == 5) {
            _loadReports();
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
          BottomNavigationBarItem(
            icon: Icon(Icons.report_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
