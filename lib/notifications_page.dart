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
    '30d': Duration(days: 30),
  };

  static const _readStates = [
    'All',
    'Unread',
    'Read',
  ];

  static const int _perPage = 12;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedReadState = 'All';
  String _selectedType = 'All';
  String _selectedRange = '30d';
  int _page = 0;

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

    if (!mounted || accountId == null || _notificationsChannel != null) {
      return;
    }

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

    await DatabaseService.deleteOldNotifications();

    final notifications = await DatabaseService.getCurrentNotifications(
      type: _selectedType,
      age: _timeRanges[_selectedRange],
      unreadOnly: _selectedReadState == 'Unread',
      readOnly: _selectedReadState == 'Read',
      limit: _perPage,
      offset: _page * _perPage,
    );

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _showFullMessage(Map<String, dynamic> item) async {
    final scheme = Theme.of(context).colorScheme;
    final title = item['title']?.toString() ?? 'Notification';
    final body = item['body']?.toString() ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          backgroundColor: dialogScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            style: TextStyle(color: dialogScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Text(
              body,
              style: TextStyle(color: dialogScheme.onSurface),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (item['is_read'] != true) {
      await DatabaseService.markNotificationRead(
        item['notification_id'].toString(),
      );
      await _loadNotifications();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notification opened',
          style: TextStyle(color: scheme.onInverseSurface),
        ),
      ),
    );
  }

  Widget _filters() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
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

              setState(() {
                _selectedType = value;
                _page = 0;
              });

              _loadNotifications();
            },
          ),
          DropdownButton<String>(
            value: _selectedReadState,
            items: _readStates
                .map((state) => DropdownMenuItem(value: state, child: Text(state)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedReadState = value;
                _page = 0;
              });

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

              setState(() {
                _selectedRange = value;
                _page = 0;
              });

              _loadNotifications();
            },
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _page <= 0
                  ? null
                  : () {
                      setState(() => _page--);
                      _loadNotifications();
                    },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Text('Page ${_page + 1}'),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _notifications.length < _perPage
                  ? null
                  : () {
                      setState(() => _page++);
                      _loadNotifications();
                    },
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    final isRead = item['is_read'] == true;
    final type = item['notification_type']?.toString() ?? 'System';

    return Card(
      color: isRead
          ? scheme.surfaceContainerHighest.withAlpha(120)
          : scheme.primaryContainer.withAlpha(150),
      child: ListTile(
        leading: Icon(
          isRead ? Icons.notifications_none : Icons.notifications_active,
          color: isRead ? scheme.onSurfaceVariant : scheme.primary,
        ),
        title: Text(
          item['title']?.toString() ?? 'Notification',
          style: TextStyle(
            color: isRead ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['body']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isRead ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type,
              style: TextStyle(
                color: isRead ? scheme.onSurfaceVariant : scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () async {
            if (isRead) {
              await DatabaseService.markNotificationUnread(
                item['notification_id'].toString(),
              );
            } else {
              await DatabaseService.markNotificationRead(
                item['notification_id'].toString(),
              );
            }

            await _loadNotifications();
          },
          child: Text(isRead ? 'Mark unread' : 'Mark read'),
        ),
        onTap: () => _showFullMessage(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            children: [
                              const SizedBox(height: 160),
                              Center(
                                child: Text(
                                  'No notifications found',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: _notifications.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _notifications.length) {
                                return _pager();
                              }

                              return _notificationCard(_notifications[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}