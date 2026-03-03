import 'package:flutter/material.dart';
import '../config/theme.dart';

class PendingSettlementsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const PendingSettlementsBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MerchantTheme.primary.withOpacity(0.15),
              MerchantTheme.accent.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MerchantTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MerchantTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: MerchantTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count request${count == 1 ? '' : 's'} ready to settle',
                    style: const TextStyle(
                      color: MerchantTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    'Tap to execute approved transactions',
                    style: TextStyle(
                      color: MerchantTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: MerchantTheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
