import 'package:flutter/material.dart';
import 'services/database_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _sellerApplications = [];
  bool _isLoading = false;
  late List<double> _dailySales;
  final List<Map<String, dynamic>> _mockOrders = [
    {'id': 'ORD001', 'date': '2024-10-01', 'customer': 'John Doe', 'items': 3, 'total': 1250.00},
    {'id': 'ORD002', 'date': '2024-10-01', 'customer': 'Jane Smith', 'items': 2, 'total': 850.00},
    {'id': 'ORD003', 'date': '2024-10-02', 'customer': 'Bob Johnson', 'items': 4, 'total': 2100.00},
    {'id': 'ORD004', 'date': '2024-10-02', 'customer': 'Alice Brown', 'items': 1, 'total': 450.00},
    {'id': 'ORD005', 'date': '2024-10-03', 'customer': 'Charlie Wilson', 'items': 5, 'total': 3200.00},
  ];

  double get _totalSales => _mockOrders.fold(0.0, (sum, order) => sum + order['total']);
  int get _totalOrders => _mockOrders.length;
  double get _avgOrderValue => _totalSales / _totalOrders;

  @override
  void initState() {
    super.initState();
    _dailySales = [800, 1450, 2100, 1800, 3200];
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        addressLine: _formatSellerAddress(app),
        city: app['city']?.toString() ?? '',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
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
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Applicant', '${app['account']?['firstname'] ?? 'N/A'} ${app['account']?['surname'] ?? ''}'),
              _detailRow('Email', app['account']?['email'] ?? 'N/A'),
              _detailRow('Store Name', app['store_name'] ?? 'N/A'),
              _detailRow('Phone', app['contact_phone'] ?? 'N/A'),
              _detailRow('Business Address', _formatSellerAddress(app)),
              _detailRow('Province', app['province'] ?? 'N/A'),
              _detailRow('Municipality/City', app['city'] ?? 'N/A'),
              _detailRow('Barangay', app['barangay'] ?? 'N/A'),
              _detailRow('Street', app['street'] ?? 'N/A'),
              _detailRow('House Number', app['house_number'] ?? 'N/A'),
              _detailRow('Status', app['status'] ?? 'N/A'),
              _detailRow('Submitted', app['submission_date'] ?? 'N/A'),
              if (app['store_description'] != null && app['store_description'].isNotEmpty)
                ...[
                  const SizedBox(height: 8),
                  const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(app['store_description']),
                ],
            ],
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
              child: const Text('Approve', style: TextStyle(color: Colors.green)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSellerAddress(Map<String, dynamic> app) {
    final parts = [
      app['house_number'],
      app['street'],
      app['barangay'],
      app['city'],
      app['province'],
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

  Widget _buildSellerApplicationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sellerApplications.isEmpty) {
      return const Center(
        child: Text('No seller applications'),
      );
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
                Text('${app['account']?['firstname'] ?? 'Unknown'} ${app['account']?['surname'] ?? ''}'),
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
                Expanded(child: _metricCard('Total Sales', '₱${_totalSales.toStringAsFixed(0)}', Icons.trending_up, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _metricCard('Total Orders', '$_totalOrders', Icons.shopping_cart, Colors.blue)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _metricCard('Avg Order Value', '₱${_avgOrderValue.toStringAsFixed(0)}', Icons.attach_money, Colors.orange),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Daily Revenue'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) => _revenueBar(_dailySales[i], i)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSalesReportTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mockOrders.length,
      itemBuilder: (context, index) {
        final order = _mockOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text('#${order['id'].substring(3)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(order['customer']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${order['date']} | Items: ${order['items']}'),
                Text('Total: ₱${order['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showOrderDetails(order),
          ),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order['customer']}'),
            Text('Date: ${order['date']}'),
            Text('Items: ${order['items']}'),
            Text('Total: ₱${order['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
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
        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [_buildDashboardTab(), _buildSalesReportTab(), _buildSellerApplicationsTab()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF2d8f4e),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              if (_currentIndex == 2) {
                _loadSellerApplications();
              } else {
                setState(() {});
              }
            },
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
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Sellers'),
        ],
      ),
    );
  }
}
