import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/transaction.dart';

class RecentTransactionTile extends StatelessWidget {
  final Transaction txn;
  final VoidCallback? onTap;

  const RecentTransactionTile({
    super.key,
    required this.txn,
    this.onTap,
  });

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
    final isDeposit = txn.isDeposit;
    final color = isDeposit ? MerchantTheme.accent : MerchantTheme.danger;
    final icon = isDeposit ? Icons.arrow_downward : Icons.arrow_upward;
    final amount = double.tryParse(txn.amount)?.toStringAsFixed(2) ?? txn.amount;

    final statusColor = {
      'completed': MerchantTheme.accent,
      'approved': const Color(0xFF3B82F6),
      'pending': MerchantTheme.warning,
      'rejected': const Color(0xFFEF4444),
      'failed': MerchantTheme.danger,
    }[txn.status] ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: MerchantTheme.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.customerName ?? txn.providerDisplayName,
                    style: const TextStyle(
                      color: MerchantTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          txn.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(txn.createdAt),
                        style: const TextStyle(
                          color: MerchantTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              'GH₵ $amount',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
