import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/database_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationsChannel;
  static const _types = [
    'All',
    'System',
    'Commerce',
    'Delivery',
    'Account',
    'Promotion',
    'Application',
  ];
  static const _timeRanges = {
    '24hr': Duration(hours: 24),
    '1w': Duration(days: 7),
    '1m': Duration(days: 30),
    '6m': Duration(days: 183),
    '1yr': Duration(days: 365),
    'Full': null,
  };

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedType = 'All';
  String _selectedRange = 'Full';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    final channel = _notificationsChannel;
    if (channel != null) _supabase.removeChannel(channel);
    super.dispose();
  }

  Future<void> _subscribeToNotifications() async {
    final accountId = await DatabaseService.getCurrentAccountId();
    if (!mounted || accountId == null || _notificationsChannel != null) return;
    _notificationsChannel = _supabase
        .channel('notifications-$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (_) => _loadNotifications(),
        )
        .subscribe();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await DatabaseService.getCurrentNotifications(
      type: _selectedType,
      age: _timeRanges[_selectedRange],
    );
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  void _showFullMessage(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['title']?.toString() ?? 'Notification'),
        content: SingleChildScrollView(
          child: Text(item['body']?.toString() ?? ''),
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

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DropdownButton<String>(
            value: _selectedType,
            items: _types
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedType = value);
              _loadNotifications();
            },
          ),
          DropdownButton<String>(
            value: _selectedRange,
            items: _timeRanges.keys
                .map((range) => DropdownMenuItem(value: range, child: Text(range)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedRange = value);
              _loadNotifications();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: _notifications.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Center(child: Text('No notifications found')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final item = _notifications[index];
                              final isRead = item['is_read'] == true;
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    isRead
                                        ? Icons.notifications_none
                                        : Icons.notifications_active,
                                    color: isRead
                                        ? Colors.grey
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                  title: Text(
                                    item['title']?.toString() ?? 'Notification',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['body']?.toString() ?? ''),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['notification_type']?.toString() ??
                                            'System',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => _showFullMessage(item),
                                    child: const Text('Read more'),
                                  ),
                                  onTap: () async {
                                    await DatabaseService.markNotificationRead(
                                      item['notification_id'].toString(),
                                    );
                                    _loadNotifications();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
