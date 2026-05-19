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
  final _reportSearchController = TextEditingController();
  String _salesGroupFilter = 'Week';
  String _commissionRange = 'Days';
  String _sellerApplicationFilter = 'Pending Review';
  String _riderApplicationFilter = 'Pending Review';
  String _reportTypeFilter = 'All';

  static const List<String> _applicationStatusFilters = [
    'Pending Review',
    'Approved',
    'Rejected',
    'All',
  ];
  static const List<String> _commissionRanges = ['Days', 'Weeks', 'Months'];
  static const List<String> _reportTypeFilters = [
    'All',
    'Store',
    'Product',
  ];
  static const List<String> _salesGroupFilters = [
    'Week',
    'Month',
    'Year',
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

  
  @override
  void dispose() {
    _reportSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAdminOrders();
    _loadSellerApplications();
    _loadRiderApplications();
    _loadCoupons();
    _loadReports();
    _loadProfile();
  }

  void _setAdminTab(int index) {
    setState(() => _currentIndex = index);

    if (index == 2) {
      _loadSellerApplications();
    } else if (index == 3) {
      _loadRiderApplications();
    } else if (index == 4) {
      _loadCoupons();
    } else if (index == 5) {
      _loadReports();
    } else {
      _loadAdminOrders();
    }
  }

  Widget _adminNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _setAdminTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 86,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline.withAlpha(70),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardActionCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupedAdminGains() {
    final grouped = <String, Map<String, dynamic>>{};

    for (final order in _successfulOrders) {
      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (date == null) continue;

      final key = _salesPeriodKey(date);
      final label = _salesPeriodLabel(date);

      final row = grouped.putIfAbsent(
        key,
        () => {
          'key': key,
          'label': label,
          'date': date,
          'orders': 0,
          'gross': 0.0,
          'commission': 0.0,
          'ordersList': <Map<String, dynamic>>[],
        },
      );

      row['orders'] = (row['orders'] as int) + 1;
      row['gross'] = (row['gross'] as double) + _toDouble(order['total_amount']);
      row['commission'] =
          (row['commission'] as double) + _toDouble(order['admin_commission']);

      (row['ordersList'] as List<Map<String, dynamic>>).add(order);

      final currentDate = row['date'] as DateTime;
      if (date.isAfter(currentDate)) {
        row['date'] = date;
      }
    }

    final rows = grouped.values.toList()
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return rows;
  }

  String _salesPeriodKey(DateTime date) {
    if (_salesGroupFilter == 'Year') {
      return '${date.year}';
    }

    if (_salesGroupFilter == 'Month') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }

    final weekStart = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));

    return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  String _salesPeriodLabel(DateTime date) {
    if (_salesGroupFilter == 'Year') {
      return '${date.year}';
    }

    if (_salesGroupFilter == 'Month') {
      return '${_monthName(date.month)} ${date.year}';
    }

    final weekStart = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[(month - 1).clamp(0, 11)];
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
    final cancelledOrders = _orders.where((order) {
      final status = order['order_status']?.toString().toLowerCase() ?? '';
      return status == 'cancelled' || status == 'canceled';
    }).length;

    final pendingSellers = _sellerApplications
        .where((app) => app['status']?.toString() == 'Pending Review')
        .length;

    final pendingRiders = _riderApplications
        .where((app) => app['status']?.toString() == 'Pending Review')
        .length;

    final activeCoupons =
        _coupons.where((coupon) => coupon['is_active'] != false).length;

    final pendingReports = [
      ..._storeReports,
      ..._productReports,
    ].where((report) {
      final status = report['status']?.toString().toLowerCase() ?? 'pending';
      return status == 'pending' || status == 'open';
    }).length;

    final recentOrders = [..._orders]
      ..sort((a, b) {
        final aDate = a['order_date']?.toString() ?? '';
        final bDate = b['order_date']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAdminOrders();
        await _loadSellerApplications();
        await _loadRiderApplications();
        await _loadCoupons();
        await _loadReports();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Admin Overview',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Business health, commissions, applications, and reports',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Commission',
                  '₱${_totalCommission.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Orders',
                  '$_totalOrders',
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Avg Gain',
                  '₱${_avgCommission.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Cancelled',
                  '$cancelledOrders',
                  Icons.cancel_outlined,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _sectionTitle('Needs Attention'),

          Row(
            children: [
              Expanded(
                child: _dashboardActionCard(
                  title: 'Seller Apps',
                  value: '$pendingSellers pending',
                  icon: Icons.storefront_outlined,
                  color: Colors.purple,
                  onTap: () => _setAdminTab(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dashboardActionCard(
                  title: 'Rider Apps',
                  value: '$pendingRiders pending',
                  icon: Icons.delivery_dining,
                  color: Colors.teal,
                  onTap: () => _setAdminTab(3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _dashboardActionCard(
                  title: 'Reports',
                  value: '$pendingReports open',
                  icon: Icons.report_outlined,
                  color: Colors.deepOrange,
                  onTap: () => _setAdminTab(5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dashboardActionCard(
                  title: 'Coupons',
                  value: '$activeCoupons active',
                  icon: Icons.local_offer_outlined,
                  color: Colors.indigo,
                  onTap: () => _setAdminTab(4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _sectionTitle('Commission Trend'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterChips(
                  values: _commissionRanges,
                  selected: _commissionRange,
                  onSelected: (value) => setState(() => _commissionRange = value),
                ),
                const SizedBox(height: 12),
                _commissionLineChart(_commissionSeries()),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle('Recent Orders'),

          if (recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No orders yet')),
            )
          else
            ...recentOrders.take(5).map((order) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(_customerName(order)),
                  subtitle: Text(
                    '${_formatDate(order['order_date'])} | ${_itemCount(order)} item(s)',
                  ),
                  trailing: Text(
                    '₱${_toDouble(order['admin_commission']).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _showOrderDetails(order),
                ),
              );
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSalesReportTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rows = _groupedAdminGains();
    final totalCommission = rows.fold<double>(
      0,
      (sum, row) => sum + (row['commission'] as double),
    );
    final totalGross = rows.fold<double>(
      0,
      (sum, row) => sum + (row['gross'] as double),
    );
    final totalOrders = rows.fold<int>(
      0,
      (sum, row) => sum + (row['orders'] as int),
    );

    return RefreshIndicator(
      onRefresh: _loadAdminOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sales Gains',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Your admin commission grouped by $_salesGroupFilter',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Your Gain',
                  '₱${totalCommission.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Gross Sales',
                  '₱${totalGross.toStringAsFixed(2)}',
                  Icons.payments_outlined,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Orders',
                  '$totalOrders',
                  Icons.receipt_long,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Avg Gain',
                  totalOrders == 0
                      ? '₱0.00'
                      : '₱${(totalCommission / totalOrders).toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          _filterChips(
            values: _salesGroupFilters,
            selected: _salesGroupFilter,
            onSelected: (value) => setState(() => _salesGroupFilter = value),
          ),

          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No successful sales yet')),
            )
          else
            ...rows.map((row) {
              final orders = row['ordersList'] as List<Map<String, dynamic>>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    row['label'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${row['orders']} order(s) | Gross ₱${(row['gross'] as double).toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    '₱${(row['commission'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: orders.map((order) {
                    return ListTile(
                      dense: true,
                      title: Text(_customerName(order)),
                      subtitle: Text(
                        '${_formatDate(order['order_date'])} | ${_itemCount(order)} item(s)',
                      ),
                      trailing: Text(
                        '₱${_toDouble(order['admin_commission']).toStringAsFixed(2)}',
                      ),
                      onTap: () => _showOrderDetails(order),
                    );
                  }).toList(),
                ),
              );
            }),
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
        bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 700;

          if (!isMobile) {
            return NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _setAdminTab,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Sales'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Sellers'),
                NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Riders'),
                NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Coupons'),
                NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Reports'),
              ],
            );
          }

          return SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  _adminNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                  _adminNavItem(1, Icons.analytics_outlined, Icons.analytics, 'Sales'),
                  _adminNavItem(2, Icons.people_outline, Icons.people, 'Sellers'),
                  _adminNavItem(3, Icons.delivery_dining_outlined, Icons.delivery_dining, 'Riders'),
                  _adminNavItem(4, Icons.local_offer_outlined, Icons.local_offer, 'Coupons'),
                  _adminNavItem(5, Icons.report_outlined, Icons.report, 'Reports'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
