import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  // Mock sales data (replace with real Supabase 'orders' table later)
  final List<Map<String, dynamic>> _mockOrders = [
    {'id': 'ORD001', 'date': '2024-10-01', 'customer': 'John Doe', 'items': 3, 'total': 1250.00},
    {'id': 'ORD002', 'date': '2024-10-01', 'customer': 'Jane Smith', 'items': 2, 'total': 850.00},
    {'id': 'ORD003', 'date': '2024-10-02', 'customer': 'Bob Johnson', 'items': 4, 'total': 2100.00},
    {'id': 'ORD004', 'date': '2024-10-02', 'customer': 'Alice Brown', 'items': 1, 'total': 450.00},
    {'id': 'ORD005', 'date': '2024-10-03', 'customer': 'Charlie Wilson', 'items': 5, 'total': 3200.00},
  ];

  // Dashboard metrics (mock)
  double get _totalSales => _mockOrders.fold(0.0, (sum, order) => sum + order['total']);
  int get _totalOrders => _mockOrders.length;
  double get _avgOrderValue => _totalSales / _totalOrders;

  late List<double> _dailySales; // for chart

  @override
  void initState() {
    super.initState();
    _dailySales = [800, 1450, 2100, 1800, 3200]; // mock daily
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section
          _heroSection(),
          const SizedBox(height: 20),

          // Metrics cards
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

          // Revenue chart (simple bars)
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
    final tabs = [_buildDashboardTab(), _buildSalesReportTab()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF2d8f4e),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Sales'),
        ],
      ),
    );
  }
}

