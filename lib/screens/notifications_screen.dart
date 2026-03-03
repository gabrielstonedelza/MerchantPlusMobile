import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifications = await api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    final api = context.read<AuthProvider>().api;
    if (api == null || notification.isRead) return;

    try {
      await api.markNotificationRead(notification.id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == notification.id);
          if (idx != -1) {
            _notifications[idx] = AppNotification(
              id: notification.id,
              category: notification.category,
              title: notification.title,
              message: notification.message,
              isRead: true,
              readAt: DateTime.now().toIso8601String(),
              relatedObjectId: notification.relatedObjectId,
              createdAt: notification.createdAt,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;

    try {
      await api.markAllNotificationsRead();
      if (mounted) _loadNotifications();
    } catch (_) {}
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'transaction':
        return Icons.swap_horiz_rounded;
      case 'approval':
        return Icons.check_circle_outline;
      case 'customer':
        return Icons.person_outline;
      case 'security':
        return Icons.shield_outlined;
      case 'team':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'transaction':
        return MerchantTheme.accent;
      case 'approval':
        return const Color(0xFF3B82F6);
      case 'customer':
        return MerchantTheme.primary;
      case 'security':
        return MerchantTheme.danger;
      case 'team':
        return MerchantTheme.warning;
      default:
        return MerchantTheme.textSecondary;
    }
  }

  String _timeAgo(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: MerchantTheme.background,
      appBar: AppBar(
        backgroundColor: MerchantTheme.background,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: MerchantTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: MerchantTheme.textPrimary),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: MerchantTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style:
                              const TextStyle(color: MerchantTheme.danger)),
                      TextButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          return _NotificationTile(
                            notification: n,
                            icon: _iconForCategory(n.category),
                            color: _colorForCategory(n.category),
                            timeAgo: _timeAgo(n.createdAt),
                            onTap: () => _markAsRead(n),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MerchantTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 40,
              color: MerchantTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: MerchantTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'ll see important updates\nand alerts here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MerchantTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color color;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: notification.isRead
          ? MerchantTheme.surface
          : MerchantTheme.primary.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: notification.isRead
              ? MerchantTheme.border
              : MerchantTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: MerchantTheme.textPrimary,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            color: MerchantTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: MerchantTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: MerchantTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
