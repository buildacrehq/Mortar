import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/notifications/models/app_notification.dart';
import 'package:buildacre_crm/features/notifications/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationType? _filter;
  late List<AppNotification> _notifs;

  @override
  void initState() {
    super.initState();
    // Build fresh on open
    _notifs =
        ref.read(notificationsProvider.notifier).buildNotifications();
  }

  @override
  Widget build(BuildContext context) {
    // Watch readIds so UI updates when marked read
    ref.watch(notificationsProvider);

    final filtered = _filter == null
        ? _notifs
        : _notifs.where((n) => n.type == _filter).toList();

    final unreadCount = _notifs.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref
                    .read(notificationsProvider.notifier)
                    .markAllRead(_notifs.map((n) => n.id).toList());
                setState(() {
                  for (final n in _notifs) {
                    n.isRead = true;
                  }
                });
              },
              child: Text(
                'Mark all read',
                style: TextStyle(color: AppColors.gold, fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          if (unreadCount > 0)
            Container(
              width: double.infinity,
              color: AppColors.navy.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '$unreadCount unread',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (_, i) => _NotifTile(
                      notif: filtered[i],
                      onTap: () {
                        ref
                            .read(notificationsProvider.notifier)
                            .markRead(filtered[i].id);
                        setState(() => filtered[i].isRead = true);
                        if (filtered[i].leadId != null) {
                          context.push('/leads/${filtered[i].leadId}');
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final types = [
      (null, 'All'),
      (NotificationType.alert, 'Alerts'),
      (NotificationType.assignment, 'Assignments'),
      (NotificationType.callQuality, 'Calls'),
      (NotificationType.stageUpdate, 'Updates'),
      (NotificationType.futureDue, 'Future'),
    ];

    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: types.map((t) {
          final isSelected = _filter == t.$1;
          final count = t.$1 == null
              ? _notifs.where((n) => !n.isRead).length
              : _notifs.where((n) => n.type == t.$1 && !n.isRead).length;
          return GestureDetector(
            onTap: () => setState(() => _filter = t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSelected ? AppColors.navy : AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold
                            : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'All caught up!',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'No notifications for this filter',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notif.isRead ? Colors.transparent : notif.color.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: notif.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(notif.icon, color: notif.color, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: notif.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notif.typeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: notif.color,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(notif.createdAt),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      if (!notif.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: notif.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
