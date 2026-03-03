import 'package:flutter/material.dart';
import '../config/theme.dart';

class BalanceSummaryCard extends StatelessWidget {
  final int transactionCount;
  final double totalVolume;
  final int depositCount;
  final int withdrawalCount;
  final bool loading;

  const BalanceSummaryCard({
    super.key,
    required this.transactionCount,
    required this.totalVolume,
    required this.depositCount,
    required this.withdrawalCount,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2233),
            Color(0xFF151824),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MerchantTheme.primary.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: MerchantTheme.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: loading
          ? const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MerchantTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "TODAY'S ACTIVITY",
                        style: TextStyle(
                          color: MerchantTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'GH₵ ${_formatAmount(totalVolume)}',
                  style: const TextStyle(
                    color: MerchantTheme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$transactionCount transaction${transactionCount == 1 ? '' : 's'} today',
                  style: const TextStyle(
                    color: MerchantTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Deposit / Withdrawal split
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.arrow_downward,
                      label: 'Deposits',
                      value: '$depositCount',
                      color: MerchantTheme.accent,
                    ),
                    const SizedBox(width: 24),
                    _MiniStat(
                      icon: Icons.arrow_upward,
                      label: 'Withdrawals',
                      value: '$withdrawalCount',
                      color: MerchantTheme.danger,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: MerchantTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
