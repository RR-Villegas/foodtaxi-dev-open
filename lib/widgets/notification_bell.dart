import 'package:flutter/material.dart';

import '../services/database_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DatabaseService.getCurrentNotifications(limit: 3);
    if (!mounted) return;
    setState(() => _items = items);
  }

  void _showNotifications() {
    _load();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                margin: const EdgeInsets.only(left: 12, top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 8),
                      color: Colors.black26,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No notifications'),
                      )
                    else
                      ..._items.map((item) => _NotificationPreview(item: item)),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/notifications');
                        },
                        child: const Text('More'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => item['is_read'] != true).length;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: _showNotifications,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount.toString()),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['notification_type']?.toString() ?? 'System';
    final title = item['title']?.toString() ?? 'Notification';
    final body = item['body']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item['is_read'] == true ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(type)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () async {
                  await DatabaseService.markNotificationRead(
                    item['notification_id'].toString(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(child: Text(body)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Read more'),
            ),
          ),
        ],
      ),
    );
  }
}
