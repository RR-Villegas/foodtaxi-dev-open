import 'package:flutter/material.dart';

import '../services/database_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<Map<String, dynamic>> _items = [];
  bool _isOpen = false;
  int _page = 0;
  int _unreadCount = 0;

  static const int _perPage = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DatabaseService.deleteOldNotifications();

    final items = await DatabaseService.getCurrentNotifications(
      limit: _perPage,
      offset: _page * _perPage,
      unreadOnly: false,
      age: const Duration(days: 30),
    );

    final unread = await DatabaseService.getUnreadNotificationCount(
      age: const Duration(days: 30),
    );

    if (!mounted) return;

    setState(() {
      _items = items;
      _unreadCount = unread;
    });
  }

  Future<void> _showNotifications() async {
    if (_isOpen) return;

    setState(() => _isOpen = true);

    _page = 0;
    await _load();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scheme = Theme.of(dialogContext).colorScheme;
            final screenHeight = MediaQuery.of(dialogContext).size.height;
            final maxListHeight = screenHeight * 0.46;

            Future<void> reloadDialog() async {
              await _load();

              if (dialogContext.mounted) {
                setDialogState(() {});
              }
            }

            return Dialog(
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: screenHeight - 48,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No notifications',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxListHeight,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];

                              return _NotificationPreview(
                                item: item,
                                onRead: reloadDialog,
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _page <= 0
                                  ? null
                                  : () async {
                                      _page--;
                                      await reloadDialog();
                                    },
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Prev'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _items.length < _perPage
                                  ? null
                                  : () async {
                                      _page++;
                                      await reloadDialog();
                                    },
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Next'),
                            ),
                          ),
                        ],
                      ),

                      Divider(color: scheme.outline.withAlpha(80)),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.pushNamed(context, '/notifications');
                          },
                          child: const Text('Open Full Page'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _showNotifications,
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text(
          _unreadCount > 99 ? '99+' : _unreadCount.toString(),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  final Map<String, dynamic> item;
  final Future<void> Function() onRead;

  const _NotificationPreview({
    required this.item,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRead = item['is_read'] == true;
    final type = item['notification_type']?.toString() ?? 'System';
    final title = item['title']?.toString() ?? 'Notification';
    final body = item['body']?.toString() ?? '';

    final background = isRead
        ? scheme.surfaceContainerHighest.withAlpha(120)
        : scheme.primaryContainer.withAlpha(150);

    final borderColor = isRead
        ? scheme.outline.withAlpha(90)
        : scheme.primary.withAlpha(120);

    final textColor = isRead
        ? scheme.onSurfaceVariant
        : scheme.onPrimaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
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
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () async {
                  await DatabaseService.markNotificationRead(
                    item['notification_id'].toString(),
                  );
                  await onRead();
                },
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: textColor,
                ),
              ),
            ],
          ),

          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
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

                await DatabaseService.markNotificationRead(
                  item['notification_id'].toString(),
                );
                await onRead();
              },
              child: const Text('Read more'),
            ),
          ),
        ],
      ),
    );
  }
}