import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/adaptive_menu_item.dart';
import 'widgets/notification_bell.dart';
import 'widgets/role_sidebar.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Timer? _timeRolloverTimer;
  DateTime _lastTimeTick = DateTime.now();
  DateTimeRange? _customSalesRange;
  DateTime _salesAnchorDate = DateTime.now();
  int _currentIndex = 0;
  int _recentOrdersPage = 0;
  int _auditLogPage = 0;
  bool _isLoadingAuditLogs = false;
  bool _auditLogHasNextPage = false;
  String? _auditLogError;
  List<Map<String, dynamic>> _auditLogs = [];
  static const int _recentOrdersPerPage = 5;
  static const int _auditLogsPerPage = 50;
  List<Map<String, dynamic>> _sellerApplications = [];
  List<Map<String, dynamic>> _riderApplications = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _storeReports = [];
  List<Map<String, dynamic>> _productReports = [];
  List<Map<String, dynamic>> _buyerReports = [];
  List<Map<String, dynamic>> _marketFlags = [];
  String _marketFlagStatusFilter = 'open';
  int _marketFlagPage = 0;
  static const int _marketFlagsPerPage = 10;
  static const List<String> _marketFlagStatusFilters = [
    'open',
    'reviewing',
    'resolved',
    'dismissed',
    'All',
  ];
  Map<String, dynamic>? _account;
  bool _isLoading = false;
  final _reportSearchController = TextEditingController();
  String _salesGroupFilter = 'Week';
  String _commissionRange = 'Days';
  static const String _commissionRangePrefKey = 'admin_commission_range';
  String _sellerApplicationFilter = 'Pending Review';
  String _riderApplicationFilter = 'Pending Review';
  String _reportTypeFilter = 'All';
  bool _loadingTerms = false;
  bool _savingTerms = false;
  final List<Map<String, dynamic>> _termsSections = [];
  final _termsSummaryController = TextEditingController();
  final List<TextEditingController> _termsTitleControllers = [];
  final List<TextEditingController> _termsBodyControllers = [];

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
    'Buyer',
  ];
  static const List<String> _salesGroupFilters = [
    'Day',
    'Week',
    'Month',
    'Year',
    'Custom',
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

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - 1;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    return ((date.difference(firstMonday).inDays) ~/ 7) + 1;
  }

  @override
  void dispose() {
    _reportSearchController.dispose();
    _timeRolloverTimer?.cancel();
    _termsSummaryController.dispose();
    for (final controller in _termsTitleControllers) {
      controller.dispose();
    }
    for (final controller in _termsBodyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _loadAdminPreferences();

    _timeRolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();

      final dayChanged = now.day != _lastTimeTick.day ||
          now.month != _lastTimeTick.month ||
          now.year != _lastTimeTick.year;

      final monthChanged = now.month != _lastTimeTick.month ||
          now.year != _lastTimeTick.year;

      final yearChanged = now.year != _lastTimeTick.year;

      final weekChanged = now.weekday < _lastTimeTick.weekday ||
          now.difference(_lastTimeTick).inDays >= 7;

      if (!mounted) return;

      if (_salesGroupFilter == 'Day' && dayChanged) {
        setState(() => _salesAnchorDate = now);
      } else if (_salesGroupFilter == 'Week' && weekChanged) {
        setState(() => _salesAnchorDate = now);
      } else if (_salesGroupFilter == 'Month' && monthChanged) {
        setState(() => _salesAnchorDate = now);
      } else if (_salesGroupFilter == 'Year' && yearChanged) {
        setState(() => _salesAnchorDate = now);
      }

      _lastTimeTick = now;
    });

    _loadAdminOrders();
    _loadSellerApplications();
    _loadRiderApplications();
    _loadCoupons();
    _loadReports();
    _loadMarketFlags();
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
    } else if (index == 6) {
      _loadMarketFlags();
    } else if (index == 7) {
      _loadTermsEditor();
    } else if (index == 8) {
      _loadAuditLogs();
    } else {
      _loadAdminOrders();
    }
  }

  Future<void> _loadAuditLogs({int page = 0}) async {
    setState(() {
      _isLoadingAuditLogs = true;
      _auditLogError = null;
    });

    try {
      final events = await DatabaseService.fetchAdminAuditEvents(
        limit: _auditLogsPerPage + 1,
        offset: page * _auditLogsPerPage,
      );
      if (!mounted) return;
      setState(() {
        _auditLogs = events.take(_auditLogsPerPage).toList();
        _auditLogHasNextPage = events.length > _auditLogsPerPage;
        _auditLogPage = page;
        _isLoadingAuditLogs = false;
      });
    } catch (error) {
      debugPrint('Failed to load admin audit logs: $error');
      if (!mounted) return;
      setState(() {
        _isLoadingAuditLogs = false;
        _auditLogError = 'Unable to load audit logs. Check access and retry.';
      });
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

  Future<void> _loadAdminPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCommissionRange = prefs.getString(_commissionRangePrefKey);

    if (!mounted) return;

    if (savedCommissionRange != null &&
        _commissionRanges.contains(savedCommissionRange)) {
      setState(() {
        _commissionRange = savedCommissionRange;
      });
    }
  }

  Future<void> _saveCommissionRangePreference(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commissionRangePrefKey, value);
  }

  List<Map<String, dynamic>> _groupedAdminGains() {
    final grouped = <String, Map<String, dynamic>>{};

    DateTime? startFilter;
    DateTime? endFilter;

    final anchor = _salesAnchorDate;

    if (_salesGroupFilter == 'Day') {
      startFilter = DateTime(anchor.year, anchor.month, anchor.day);
      endFilter = startFilter.add(const Duration(days: 1));
      
    } else if (_salesGroupFilter == 'Week') {
      startFilter = DateTime(anchor.year, anchor.month, anchor.day)
          .subtract(Duration(days: anchor.weekday - 1));

      endFilter = startFilter.add(const Duration(days: 7));
    } else if (_salesGroupFilter == 'Month') {
      startFilter = DateTime(anchor.year, anchor.month, 1);

      endFilter = DateTime(anchor.year, anchor.month + 1, 1);
    } else if (_salesGroupFilter == 'Year') {
      startFilter = DateTime(anchor.year, 1, 1);

      endFilter = DateTime(anchor.year + 1, 1, 1);
    } else if (_salesGroupFilter == 'Custom' &&
        _customSalesRange != null) {
      startFilter = _customSalesRange!.start;

      endFilter = _customSalesRange!.end.add(
        const Duration(days: 1),
      );
    }

    for (final order in _successfulOrders) {
      final date = DateTime.tryParse(
        order['order_date']?.toString() ?? '',
      );

      if (date == null) continue;

      if (startFilter != null && date.isBefore(startFilter)) {
        continue;
      }

      if (endFilter != null && !date.isBefore(endFilter)) {
        continue;
      }

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

      row['gross'] =
          (row['gross'] as double) +
          _toDouble(order['total_amount']);

      row['commission'] =
          (row['commission'] as double) +
          _toDouble(order['admin_commission']);

      (row['ordersList'] as List<Map<String, dynamic>>)
          .add(order);

      final currentDate = row['date'] as DateTime;

      if (date.isAfter(currentDate)) {
        row['date'] = date;
      }
    }

    final rows = grouped.values.toList()
      ..sort(
        (a, b) => (b['date'] as DateTime).compareTo(
          a['date'] as DateTime,
        ),
      );

    return rows;
  }

  Future<void> _pickSalesDateRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _customSalesRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _customSalesRange = picked;
        _salesGroupFilter = 'Custom';
      });
    }
  }

  String _monthName(int month) {
    const names = [
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

    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  String _salesPeriodKey(DateTime date) {
    if (_salesGroupFilter == 'Day') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.hour.toString().padLeft(2, '0')}';
    }

    if (_salesGroupFilter == 'Week') {
      return '${date.year}-W${_weekNumber(date).toString().padLeft(2, '0')}';
    }

    if (_salesGroupFilter == 'Month') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }

    if (_salesGroupFilter == 'Year') {
      return '${date.year}';
    }

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _salesPeriodLabel(DateTime date) {
    if (_salesGroupFilter == 'Day') {
      final hour = date.hour;
      final nextHour = (hour + 1) % 24;

      return '${hour.toString().padLeft(2, '0')}:00 - ${nextHour.toString().padLeft(2, '0')}:00';
    }

    if (_salesGroupFilter == 'Week') {
      return _formatDate(date);
    }

    if (_salesGroupFilter == 'Month') {
      final weekStart = DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    }

    if (_salesGroupFilter == 'Year') {
      return '${_monthName(date.month)} ${date.year}';
    }

    return _formatDate(date);
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
    final buyerReports = await DatabaseService.getAdminBuyerReports();
    final storeReports = await DatabaseService.getAdminStoreReports();
    final productReports = await DatabaseService.getAdminProductReports();
    if (!mounted) return;
    setState(() {
      _storeReports = storeReports;
      _productReports = productReports;
      _buyerReports = buyerReports;
    });
  }

  Future<void> _loadMarketFlags() async {
    final flags = await DatabaseService.getAdminMarketFlags(
      status: _marketFlagStatusFilter,
      limit: 100,
      offset: 0,
    );

    if (!mounted) return;
    setState(() => _marketFlags = flags);
  }

  Future<void> _runMarketScan() async {
    setState(() => _isLoading = true);

    final count = await DatabaseService.runUnfairMarketScan();
    await _loadMarketFlags();

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Market scan finished. $count flag(s) refreshed.')),
    );
  }

  Future<void> _applyMarketFlagAction(
    Map<String, dynamic> flag,
    String actionType,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final actionLabel = _marketActionLabel(actionType);

        return AlertDialog(
          title: Text(actionLabel),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: actionType == 'dismiss'
                    ? 'Dismiss note'
                    : 'Reason shown to seller',
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final ok = await DatabaseService.applyMarketFlagAction(
      flagId: flag['flag_id'].toString(),
      actionType: actionType,
      reason: reasonController.text,
    );

    reasonController.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Action applied' : 'Action could not be applied'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );

    if (ok) _loadMarketFlags();
  }

  String _marketActionLabel(String actionType) {
    switch (actionType) {
      case 'warn':
        return 'Warn Seller';
      case 'hide_product':
        return 'Hide Product';
      case 'suspend_store':
        return 'Suspend Store';
      case 'ban_seller':
        return 'Ban Seller';
      case 'dismiss':
        return 'Dismiss Flag';
      default:
        return 'Apply Action';
    }
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

  Widget _miniStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionSummarySelector() {
    final series = _commissionSeries().map((item) {
      return {
        ...item,
        'label': item['label']?.toString() ?? 'Unknown',
        'commission': _toDouble(item['commission']),
        'orders': _safeInt(item['orders']),
      };
    }).toList();

    final total = series.fold<double>(
      0.0,
      (sum, item) => sum + _toDouble(item['commission']),
    );

    final nonZeroItems = series
        .where((item) => _toDouble(item['commission']) > 0)
        .toList();

    final bestItem = nonZeroItems.isEmpty
        ? null
        : nonZeroItems.reduce(
            (a, b) => _toDouble(a['commission']) >= _toDouble(b['commission'])
                ? a
                : b,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commissionRanges.contains(_commissionRange)
                  ? _commissionRange
                  : _commissionRanges.first,
              decoration: const InputDecoration(
                labelText: 'Range',
                border: OutlineInputBorder(),
              ),
              items: _commissionRanges.map((range) {
                return DropdownMenuItem<String>(
                  value: range,
                  child: Text(range),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _commissionRange = value;
                });

                _saveCommissionRangePreference(value);
              },
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'Total',
                    value: '₱${total.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    label: 'Periods',
                    value: '${series.length}',
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'Best',
                    value: bestItem == null
                        ? '₱0.00'
                        : '₱${_toDouble(bestItem['commission']).toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    label: 'Best Period',
                    value: bestItem == null
                        ? 'None'
                        : bestItem['label']?.toString() ?? 'Unknown',
                    icon: Icons.star_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (series.isEmpty)
              const Text('No commission data yet.')
            else
              ...series.map((item) {
                final label = item['label']?.toString() ?? 'Unknown';
                final commission = _toDouble(item['commission']);
                final orders = _safeInt(item['orders']);

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  subtitle: Text('$orders order(s)'),
                  trailing: Text(
                    '₱${commission.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System audit log',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Metadata-only records of changes to important data.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh logs',
                onPressed: _isLoadingAuditLogs
                    ? null
                    : () => _loadAuditLogs(page: _auditLogPage),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_auditLogError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  _auditLogError!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: TextButton(
                  onPressed: () => _loadAuditLogs(page: _auditLogPage),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ),
        Expanded(
          child: _isLoadingAuditLogs && _auditLogs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
              ? const Center(child: Text('No audit events recorded yet.'))
              : RefreshIndicator(
                  onRefresh: () => _loadAuditLogs(page: _auditLogPage),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: _auditLogs.length,
                    itemBuilder: (context, index) {
                      final event = _auditLogs[index];
                      final timestamp = DateTime.tryParse(
                        event['occurred_at']?.toString() ?? '',
                      );
                      final primaryKey =
                          event['row_primary_key']?.toString() ?? '{}';
                      final actorId = event['actor_id']?.toString();
                      final operation =
                          event['operation']?.toString() ?? 'UNKNOWN';
                      final isDelete = operation == 'DELETE';
                      final operationColor = isDelete
                          ? theme.colorScheme.error
                          : operation == 'INSERT'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary;
                      final actorLabel = actorId == null
                          ? 'System'
                          : '${actorId.substring(0, actorId.length > 12 ? 12 : actorId.length)}…';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: operationColor.withAlpha(24),
                            child: Icon(
                              isDelete
                                  ? Icons.delete_outline
                                  : operation == 'INSERT'
                                  ? Icons.add
                                  : Icons.edit_outlined,
                              color: operationColor,
                            ),
                          ),
                          title: Text(
                            '$operation  ${event['table_schema']}.${event['table_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${timestamp?.toLocal().toString().split('.').first ?? 'Unknown time'}'
                            '\nActor: $actorLabel'
                            '\nKey: $primaryKey',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (_auditLogs.isNotEmpty || _auditLogPage > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Page ${_auditLogPage + 1} · ${_auditLogs.length} events',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _auditLogPage == 0 || _isLoadingAuditLogs
                      ? null
                      : () => _loadAuditLogs(page: _auditLogPage - 1),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                TextButton.icon(
                  onPressed: !_auditLogHasNextPage || _isLoadingAuditLogs
                      ? null
                      : () => _loadAuditLogs(page: _auditLogPage + 1),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
          ),
      ],
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
      ..._buyerReports,
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
          const Text(
            'Admin Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

          _sectionTitle('Commission Summary'),

          _commissionSummarySelector(),

          const SizedBox(height: 20),

          _sectionTitle('Recent Orders'),

          if (recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No orders yet')),
            )
          else
            _recentOrdersPager(recentOrders),

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

    String selectedRangeLabel() {
      if (_salesGroupFilter == 'Custom') {
        if (_customSalesRange == null) {
          return 'No custom range selected';
        }

        return '${_formatDate(_customSalesRange!.start)} → ${_formatDate(_customSalesRange!.end)}';
      }
      if (_salesGroupFilter == 'Day') {
        return _formatDate(_salesAnchorDate);
      }
      if (_salesGroupFilter == 'Week') {
        final start = DateTime(
          _salesAnchorDate.year,
          _salesAnchorDate.month,
          _salesAnchorDate.day,
        ).subtract(Duration(days: _salesAnchorDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${_formatDate(start)} → ${_formatDate(end)}';
      }

      if (_salesGroupFilter == 'Month') {
        return '${_monthName(_salesAnchorDate.month)} ${_salesAnchorDate.year}';
      }

      return '${_salesAnchorDate.year}';
    }

    void goPreviousPeriod() {
      setState(() {
        if (_salesGroupFilter == 'Day') {
          _salesAnchorDate = _salesAnchorDate.subtract(const Duration(days: 1));
        } else if (_salesGroupFilter == 'Week') {
          _salesAnchorDate = _salesAnchorDate.subtract(const Duration(days: 7));
        } else if (_salesGroupFilter == 'Month') {
          _salesAnchorDate = DateTime(
            _salesAnchorDate.year,
            _salesAnchorDate.month - 1,
            1,
          );
        } else if (_salesGroupFilter == 'Year') {
          _salesAnchorDate = DateTime(_salesAnchorDate.year - 1, 1, 1);
        }
      });
    }

    void goNextPeriod() {
      setState(() {
        if (_salesGroupFilter == 'Day') {
          _salesAnchorDate = _salesAnchorDate.add(const Duration(days: 1));
        } else if (_salesGroupFilter == 'Week') {
          _salesAnchorDate = _salesAnchorDate.add(const Duration(days: 7));
        } else if (_salesGroupFilter == 'Month') {
          _salesAnchorDate = DateTime(
            _salesAnchorDate.year,
            _salesAnchorDate.month + 1,
            1,
          );
        } else if (_salesGroupFilter == 'Year') {
          _salesAnchorDate = DateTime(_salesAnchorDate.year + 1, 1, 1);
        }
      });
    }

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

          _filterChips(
            values: _salesGroupFilters,
            selected: _salesGroupFilter,
            onSelected: (value) {
              setState(() {
                _salesGroupFilter = value;
              });

              if (value == 'Custom' && _customSalesRange == null) {
                _pickSalesDateRange();
              }
            },
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous period',
                    onPressed: _salesGroupFilter == 'Custom'
                        ? null
                        : goPreviousPeriod,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          selectedRangeLabel(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (_salesGroupFilter == 'Custom') ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _pickSalesDateRange,
                            icon: const Icon(Icons.date_range),
                            label: const Text('Select Date Range'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    onPressed: _salesGroupFilter == 'Custom'
                        ? null
                        : goNextPeriod,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
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

          const SizedBox(height: 14),

          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No successful sales for this period')),
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

  Widget _recentOrdersPager(List<Map<String, dynamic>> recentOrders) {
    final totalPages =
        ((recentOrders.length + _recentOrdersPerPage - 1) ~/
            _recentOrdersPerPage)
            .clamp(1, 999999);

    if (_recentOrdersPage >= totalPages) {
      _recentOrdersPage = 0;
    }

    final start = _recentOrdersPage * _recentOrdersPerPage;
    final pageOrders = recentOrders
        .skip(start)
        .take(_recentOrdersPerPage)
        .toList();

    return Column(
      children: [
        ...pageOrders.map((order) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _recentOrdersPage <= 0
                  ? null
                  : () => setState(() => _recentOrdersPage--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Page ${_recentOrdersPage + 1} of $totalPages'),
            IconButton(
              onPressed: _recentOrdersPage >= totalPages - 1
                  ? null
                  : () => setState(() => _recentOrdersPage++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
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
      ..._buyerReports.map((report) => {'type': 'Buyer', 'data': report}),
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
      final buyer = report['buyer'];
      final reporter = report['account'] ?? report['reporter'];
      final order = report['order_summary'];

      final storeText = store is Map
          ? '${store['store_name'] ?? ''} ${store['store_id'] ?? ''}'
          : '';

      final productText = product is Map
          ? '${product['name'] ?? ''} ${product['product_id'] ?? ''}'
          : '';

      final buyerText = buyer is Map
          ? '${buyer['firstname'] ?? ''} ${buyer['surname'] ?? ''} ${buyer['email'] ?? ''} ${buyer['phone_number'] ?? ''} ${buyer['account_id'] ?? ''}'
          : '';

      final reporterText = reporter is Map
          ? '${reporter['firstname'] ?? ''} ${reporter['surname'] ?? ''} ${reporter['email'] ?? ''} ${reporter['phone_number'] ?? ''} ${reporter['account_id'] ?? ''}'
          : '';

      final orderText = order is Map
          ? '${order['order_id'] ?? ''} ${order['order_status'] ?? ''} ${order['payment_status'] ?? ''} ${order['payment_method'] ?? ''}'
          : '';

      final haystack = [
        type,
        report['report_id'],
        report['reason'],
        report['details'],
        report['status'],
        report['admin_notes'],
        report['store_id'],
        report['product_id'],
        report['buyer_account_id'],
        report['reporter_account_id'],
        report['order_id'],
        storeText,
        productText,
        buyerText,
        reporterText,
        orderText,
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
    if (type == 'Buyer') {
      final buyer = report['buyer'];

      if (buyer is Map) {
        return '${buyer['firstname'] ?? ''} ${buyer['surname'] ?? ''}'.trim();
      }

      return 'Buyer';
    }
    if (type == 'Product') {
      final product = report['product'];
      if (product is Map) return product['name']?.toString() ?? 'Product';
      return report['product_id']?.toString() ?? 'Product';
    }
    final store = report['store'];
    if (store is Map) return store['store_name']?.toString() ?? 'Store';
    return report['store_id']?.toString() ?? 'Store';
  }

  Widget _buyerReportCard(Map<String, dynamic> report) {
    final buyer = report['buyer'] as Map<String, dynamic>?;
    final reporter = report['reporter'] as Map<String, dynamic>?;

    final buyerName =
        '${buyer?['firstname'] ?? ''} ${buyer?['surname'] ?? ''}'.trim();

    final reporterName =
        '${reporter?['firstname'] ?? ''} ${reporter?['surname'] ?? ''}'.trim();

    final status = report['status']?.toString() ?? 'open';

    final statusColor = switch (status) {
      'resolved' => Colors.green,
      'dismissed' => Colors.grey,
      'reviewing' => Colors.orange,
      _ => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: buyer?['profile_image_url']?.toString().trim().isNotEmpty == true
            ? NetworkImage(
                buyer!['profile_image_url'].toString().startsWith('http')
                    ? buyer['profile_image_url'].toString()
                    : DatabaseService.getProfileImageUrl(
                        buyer['profile_image_url'].toString(),
                      ),
              )
            : null,
          child: buyer?['profile_image_url']?.toString().trim().isNotEmpty == true
            ? null
            : const Icon(Icons.person),
        ),
        title: Text(
          buyerName.isEmpty ? 'Buyer Report' : buyerName,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reporter: $reporterName'),
            Text(report['reason']?.toString() ?? ''),
            const SizedBox(height: 4),
            Chip(
              label: Text(status),
              backgroundColor: statusColor.withAlpha(40),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              report['details']?.toString().trim().isEmpty ?? true
                  ? 'No details provided'
                  : report['details'].toString(),
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await DatabaseService.adminUpdateBuyerReport(
                    reportId: report['report_id'].toString(),
                    status: 'reviewing',
                  );

                  _loadReports();
                },
                child: const Text('Reviewing'),
              ),

              FilledButton(
                onPressed: () async {
                  await DatabaseService.adminUpdateBuyerReport(
                    reportId: report['report_id'].toString(),
                    status: 'resolved',
                  );

                  _loadReports();
                },
                child: const Text('Resolve'),
              ),

              OutlinedButton(
                onPressed: () async {
                  await DatabaseService.adminUpdateBuyerReport(
                    reportId: report['report_id'].toString(),
                    status: 'dismissed',
                  );

                  _loadReports();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reporterName(Map<String, dynamic> report) {
    final account = report['account'] ?? report['reporter'];

    if (account is! Map) return 'Unknown reporter';

    final first = account['firstname']?.toString() ?? '';
    final last = account['surname']?.toString() ?? '';
    final name = '$first $last'.trim();

    return name.isEmpty ? account['email']?.toString() ?? 'Unknown reporter' : name;
  }

  String _marketFlagTitle(String type) {
    switch (type) {
      case 'price_spike':
        return 'Price spike';
      case 'fake_discount_baseline':
        return 'Possible fake discount';
      case 'high_cancellation_rate':
        return 'High cancellation rate';
      case 'duplicate_listing_spam':
        return 'Duplicate listing spam';
      default:
        return 'Market flag';
    }
  }

  Color _marketFlagColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.deepPurple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  List<Map<String, dynamic>> _pageMarketFlags(List<Map<String, dynamic>> flags) {
    final start = _marketFlagPage * _marketFlagsPerPage;
    if (start >= flags.length) return [];

    final end = start + _marketFlagsPerPage > flags.length
        ? flags.length
        : start + _marketFlagsPerPage;

    return flags.sublist(start, end);
  }

  Widget _marketFlagPager(int totalItems) {
    final totalPages = totalItems == 0
        ? 1
        : ((totalItems + _marketFlagsPerPage - 1) ~/ _marketFlagsPerPage);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _marketFlagPage <= 0
                ? null
                : () => setState(() => _marketFlagPage--),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${_marketFlagPage + 1} of $totalPages'),
          IconButton(
            onPressed: _marketFlagPage >= totalPages - 1
                ? null
                : () => setState(() => _marketFlagPage++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketFlagsTab() {
    final visible = _marketFlags.where((flag) {
      if (_marketFlagStatusFilter == 'All') return true;
      return flag['status']?.toString() == _marketFlagStatusFilter;
    }).toList();

    final pageItems = _pageMarketFlags(visible);

    return RefreshIndicator(
      onRefresh: _loadMarketFlags,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Market Flags',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: _runMarketScan,
                icon: const Icon(Icons.search),
                label: const Text('Run Scan'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Review automated marketplace flags, then decide whether to dismiss, warn, hide, suspend, or ban.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _filterChips(
            values: _marketFlagStatusFilters,
            selected: _marketFlagStatusFilter,
            onSelected: (value) {
              setState(() {
                _marketFlagStatusFilter = value;
                _marketFlagPage = 0;
              });
              _loadMarketFlags();
            },
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No market flags found')),
            )
          else
            ...pageItems.map(_marketFlagAdminCard),
          _marketFlagPager(visible.length),
        ],
      ),
    );
  }

  Widget _marketFlagAdminCard(Map<String, dynamic> flag) {
    final type = flag['flag_type']?.toString() ?? '';
    final severity = flag['severity']?.toString() ?? 'medium';
    final status = flag['status']?.toString() ?? 'open';
    final reason = flag['reason']?.toString() ?? '';
    final evidence = flag['evidence'];
    final storeName = flag['store_name']?.toString() ?? '';
    final productName = flag['product_name']?.toString() ?? '';
    final sellerName = flag['seller_name']?.toString() ?? '';
    final color = _marketFlagColor(severity);

    final canAct = status == 'open' || status == 'reviewing';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(35),
          child: Icon(Icons.policy_outlined, color: color),
        ),
        title: Text(
          _marketFlagTitle(type),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sellerName.isNotEmpty) Text('Seller: $sellerName'),
              if (storeName.isNotEmpty) Text('Store: $storeName'),
              if (productName.isNotEmpty) Text('Product: $productName'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    label: Text(severity.toUpperCase()),
                    backgroundColor: color.withAlpha(35),
                    labelStyle: TextStyle(color: color),
                  ),
                  Chip(label: Text(status)),
                ],
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(reason),
          ),
          if (evidence != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                evidence.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (canAct)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _applyMarketFlagAction(flag, 'dismiss'),
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                ),
                FilledButton.icon(
                  onPressed: () => _applyMarketFlagAction(flag, 'warn'),
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Warn'),
                ),
                OutlinedButton.icon(
                  onPressed: productName.isEmpty
                      ? null
                      : () => _applyMarketFlagAction(flag, 'hide_product'),
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Hide Product'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _applyMarketFlagAction(flag, 'suspend_store'),
                  icon: const Icon(Icons.store_mall_directory_outlined),
                  label: const Text('Suspend Store'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _applyMarketFlagAction(flag, 'ban_seller'),
                  icon: const Icon(Icons.block),
                  label: const Text('Ban Seller'),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Action: ${flag['action_type'] ?? 'none'}\nNote: ${flag['admin_note'] ?? ''}',
              ),
            ),
        ],
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
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
    final now = DateTime.now();
    final grouped = <String, Map<String, dynamic>>{};

    DateTime start;
    DateTime end;

    if (_commissionRange == 'Days') {
      final today = DateTime(now.year, now.month, now.day);
      start = today.subtract(const Duration(days: 6));
      end = today.add(const Duration(days: 1));

      for (var i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final key = '${date.year}-${date.month}-${date.day}';

        grouped[key] = {
          'key': key,
          'label': _formatDate(date),
          'date': date,
          'commission': 0.0,
          'orders': 0,
        };
      }
    } else if (_commissionRange == 'Weeks') {
      final today = DateTime(now.year, now.month, now.day);
      final currentWeekStart =
          today.subtract(Duration(days: today.weekday - 1));
      start = currentWeekStart.subtract(const Duration(days: 21));
      end = currentWeekStart.add(const Duration(days: 7));

      for (var i = 0; i < 4; i++) {
        final weekStart = start.add(Duration(days: i * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final key = '${weekStart.year}-W${_weekNumber(weekStart)}';

        grouped[key] = {
          'key': key,
          'label': '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
          'date': weekStart,
          'commission': 0.0,
          'orders': 0,
        };
      }
    } else {
      start = DateTime(now.year, now.month - 5, 1);
      end = DateTime(now.year, now.month + 1, 1);

      for (var i = 0; i < 6; i++) {
        final date = DateTime(start.year, start.month + i, 1);
        final key = '${date.year}-${date.month}';

        grouped[key] = {
          'key': key,
          'label': '${_monthName(date.month)} ${date.year}',
          'date': date,
          'commission': 0.0,
          'orders': 0,
        };
      }
    }

    for (final order in _successfulOrders) {
      final date = DateTime.tryParse(order['order_date']?.toString() ?? '');
      if (date == null) continue;

      if (date.isBefore(start) || !date.isBefore(end)) continue;

      late String key;

      if (_commissionRange == 'Days') {
        key = '${date.year}-${date.month}-${date.day}';
      } else if (_commissionRange == 'Weeks') {
        final weekStart = DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday - 1));
        key = '${weekStart.year}-W${_weekNumber(weekStart)}';
      } else {
        key = '${date.year}-${date.month}';
      }

      final row = grouped[key];
      if (row == null) continue;

      row['commission'] =
          _toDouble(row['commission']) + _toDouble(order['admin_commission']);
      row['orders'] = (row['orders'] as int) + 1;
    }

    final rows = grouped.values.toList()
      ..sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

    return rows;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  Future<void> _loadTermsEditor() async {
    setState(() => _loadingTerms = true);

    try {
      final sections = await DatabaseService.getTermsVersion();

      _clearTermsControllers();

      for (final section in sections) {
        _termsSections.add(Map<String, dynamic>.from(section));

        _termsTitleControllers.add(
          TextEditingController(
            text: section['section_title']?.toString() ?? '',
          ),
        );

        _termsBodyControllers.add(
          TextEditingController(
            text: section['section_body']?.toString() ?? '',
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _loadingTerms = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingTerms = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load Terms editor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearTermsControllers() {
    for (final controller in _termsTitleControllers) {
      controller.dispose();
    }

    for (final controller in _termsBodyControllers) {
      controller.dispose();
    }

    _termsSections.clear();
    _termsTitleControllers.clear();
    _termsBodyControllers.clear();
  }

  void _addTermsSection() {
    setState(() {
      _termsSections.add({
        'icon_name': 'description',
      });

      _termsTitleControllers.add(TextEditingController());
      _termsBodyControllers.add(TextEditingController());
    });
  }

  void _removeTermsSection(int index) {
    setState(() {
      _termsSections.removeAt(index);

      final titleController = _termsTitleControllers.removeAt(index);
      final bodyController = _termsBodyControllers.removeAt(index);

      titleController.dispose();
      bodyController.dispose();
    });
  }

  void _moveTermsSection(int from, int to) {
    setState(() {
      final section = _termsSections.removeAt(from);
      final titleController = _termsTitleControllers.removeAt(from);
      final bodyController = _termsBodyControllers.removeAt(from);

      _termsSections.insert(to, section);
      _termsTitleControllers.insert(to, titleController);
      _termsBodyControllers.insert(to, bodyController);
    });
  }

  Future<void> _saveTermsVersion() async {
    final summary = _termsSummaryController.text.trim();

    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an update summary.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sections = <Map<String, dynamic>>[];

    for (var i = 0; i < _termsTitleControllers.length; i++) {
      final title = _termsTitleControllers[i].text.trim();
      final body = _termsBodyControllers[i].text.trim();

      if (title.isEmpty || body.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Section ${i + 1} needs both title and body.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      sections.add({
        'icon_name': _termsSections[i]['icon_name']?.toString() ?? 'description',
        'title': title,
        'body': body,
      });
    }

    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one Terms section.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _savingTerms = true);

    final version = await DatabaseService.createTermsVersion(
      summary: summary,
      sections: sections,
    );

    if (!mounted) return;

    setState(() => _savingTerms = false);

    if (version == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms update could not be published.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _termsSummaryController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Published Terms update as version t$version'),
        backgroundColor: Colors.green,
      ),
    );

    await _loadTermsEditor();
  }

  Widget _buildTermsAdminTab() {
    if (_loadingTerms) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadTermsEditor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Terms & Conditions Editor',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Update the current Terms. Publishing creates a new saved version automatically.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _termsSummaryController,
            decoration: const InputDecoration(
              labelText: 'Update Summary',
              hintText: 'Example: Updated refund and marketplace abuse rules',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          if (_termsTitleControllers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('No Terms sections found. Add one below.'),
              ),
            )
          else
            ...List.generate(_termsTitleControllers.length, (index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Section ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Move Up',
                            onPressed: index == 0
                                ? null
                                : () => _moveTermsSection(index, index - 1),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: 'Move Down',
                            onPressed: index == _termsTitleControllers.length - 1
                                ? null
                                : () => _moveTermsSection(index, index + 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            tooltip: 'Delete Section',
                            onPressed: () => _removeTermsSection(index),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: _termsTitleControllers[index],
                        decoration: const InputDecoration(
                          labelText: 'Section Title',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: _termsBodyControllers[index],
                        minLines: 5,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: 'Section Body',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          OutlinedButton.icon(
            onPressed: _addTermsSection,
            icon: const Icon(Icons.add),
            label: const Text('Add Section'),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _savingTerms ? null : _saveTermsVersion,
            icon: _savingTerms
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish),
            label: Text(_savingTerms ? 'Publishing...' : 'Publish Update'),
          ),

          const SizedBox(height: 40),
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
      _buildMarketFlagsTab(),
      _buildTermsAdminTab(),
      _buildAuditLogsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Panel'),
        elevation: 0,
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentIndex == 2) {
                _loadSellerApplications();
              } else if (_currentIndex == 3) {
                _loadRiderApplications();
              } else if (_currentIndex == 4) {
                _loadCoupons();
              } else if (_currentIndex == 5) {
                _loadReports();
              } else if (_currentIndex == 6) {
                _loadMarketFlags();
              } else if (_currentIndex == 7) {
                _loadTermsEditor();
              } else if (_currentIndex == 8) {
                _loadAuditLogs(page: _auditLogPage);
              } else {
                _loadAdminOrders();
              }
            },
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          return Row(
            children: [
              if (isWide)
                RoleSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _setAdminTab,
                  destinations: const [
                    RoleSidebarDestination(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                    ),
                    RoleSidebarDestination(
                      label: 'Sales',
                      icon: Icons.analytics_outlined,
                      selectedIcon: Icons.analytics,
                    ),
                    RoleSidebarDestination(
                      label: 'Sellers',
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                    ),
                    RoleSidebarDestination(
                      label: 'Riders',
                      icon: Icons.delivery_dining_outlined,
                      selectedIcon: Icons.delivery_dining,
                    ),
                    RoleSidebarDestination(
                      label: 'Coupons',
                      icon: Icons.local_offer_outlined,
                      selectedIcon: Icons.local_offer,
                    ),
                    RoleSidebarDestination(
                      label: 'Reports',
                      icon: Icons.report_outlined,
                      selectedIcon: Icons.report,
                    ),
                    RoleSidebarDestination(
                      label: 'Flags',
                      icon: Icons.policy_outlined,
                      selectedIcon: Icons.policy,
                    ),
                    RoleSidebarDestination(
                      label: 'Terms',
                      icon: Icons.description_outlined,
                      selectedIcon: Icons.description,
                    ),
                    RoleSidebarDestination(
                      label: 'System logs',
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                    ),
                  ],
                ),
              Expanded(child: tabs[_currentIndex]),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.of(context).size.width;
          final isWide = width >= 1000;
          final isMobile = width < 700;
          if (isWide) return const SizedBox.shrink();

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
                NavigationDestination(
                  icon: Icon(Icons.policy_outlined),
                  selectedIcon: Icon(Icons.policy),
                  label: 'Flags',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description),
                  label: 'Terms',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Logs',
                ),
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
                  _adminNavItem(
                    6,
                    Icons.policy_outlined,
                    Icons.policy,
                    'Flags',
                  ),
                  _adminNavItem(
                    7,
                    Icons.description_outlined,
                    Icons.description,
                    'Terms',
                  ),
                  _adminNavItem(
                    8,
                    Icons.receipt_long_outlined,
                    Icons.receipt_long,
                    'Logs',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
