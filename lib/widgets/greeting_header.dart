import 'package:flutter/material.dart';
import '../config/theme.dart';

class GreetingHeader extends StatelessWidget {
  final String fullName;
  final String initials;
  final VoidCallback onNotificationTap;
  final VoidCallback? onAvatarTap;
  final int unreadCount;

  const GreetingHeader({
    super.key,
    required this.fullName,
    required this.initials,
    required this.onNotificationTap,
    this.onAvatarTap,
    this.unreadCount = 0,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = fullName.split(' ').first;

    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MerchantTheme.primary.withOpacity(0.3),
                  MerchantTheme.primaryDark.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: MerchantTheme.primary.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: MerchantTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: const TextStyle(
                  color: MerchantTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                firstName,
                style: const TextStyle(
                  color: MerchantTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Notification bell
        GestureDetector(
          onTap: onNotificationTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MerchantTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MerchantTheme.border),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: MerchantTheme.textSecondary,
                  size: 22,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: MerchantTheme.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
