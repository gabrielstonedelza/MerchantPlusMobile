import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/balance_summary_card.dart';
import '../../widgets/recent_transaction_tile.dart';
import '../../widgets/pending_settlements_banner.dart';
import '../notifications_screen.dart';
import '../transactions/deposit_screen.dart';
import '../transactions/withdrawal_screen.dart';
import '../transactions/settlement_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../customers/customer_list_screen.dart';

class HomeTab extends StatefulWidget {
  /// Called when home finishes refreshing (e.g. after returning from deposit).
  final VoidCallback? onNeedRefresh;

  const HomeTab({super.key, this.onNeedRefresh});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Transaction> _recentTxns = [];
  int _pendingSettlements = 0;
  int _unreadNotifications = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        api.getTransactions(),
        api.getPendingSettlements(),
        api.getUnreadCount(),
      ]);
      if (mounted) {
        setState(() {
          _recentTxns = results[0] as List<Transaction>;
          _pendingSettlements = (results[1] as List<Transaction>).length;
          _unreadNotifications = results[2] as int;
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

  // Compute today's stats from recent transactions
  int get _todayCount {
    final now = DateTime.now();
    return _recentTxns.where((t) {
      try {
        final d = DateTime.parse(t.createdAt);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  double get _todayVolume {
    final now = DateTime.now();
    double total = 0;
    for (final t in _recentTxns) {
      try {
        final d = DateTime.parse(t.createdAt);
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          total += double.tryParse(t.amount) ?? 0;
        }
      } catch (_) {}
    }
    return total;
  }

  int get _todayDeposits {
    final now = DateTime.now();
    return _recentTxns.where((t) {
      try {
        final d = DateTime.parse(t.createdAt);
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day &&
            t.isDeposit;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _todayWithdrawals {
    final now = DateTime.now();
    return _recentTxns.where((t) {
      try {
        final d = DateTime.parse(t.createdAt);
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day &&
            t.isWithdrawal;
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fullName = auth.user?.fullName ?? 'User';
    final initials = fullName
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: MerchantTheme.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Greeting header
            GreetingHeader(
              fullName: fullName,
              initials: initials,
              unreadCount: _unreadNotifications,
              onNotificationTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
                // Refresh unread count after returning from notifications
                _loadData();
              },
            ),
            const SizedBox(height: 24),

            // Balance summary card
            BalanceSummaryCard(
              transactionCount: _todayCount,
              totalVolume: _todayVolume,
              depositCount: _todayDeposits,
              withdrawalCount: _todayWithdrawals,
              loading: _loading,
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MerchantTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickAction(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Deposit',
                  color: MerchantTheme.accent,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DepositScreen()),
                    );
                    _loadData();
                  },
                ),
                _QuickAction(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Withdraw',
                  color: MerchantTheme.danger,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WithdrawalScreen()),
                    );
                    _loadData();
                  },
                ),
                _QuickAction(
                  icon: Icons.people_outline_rounded,
                  label: 'Customers',
                  color: MerchantTheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerListScreen()),
                    );
                  },
                ),
                _QuickAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Settle',
                  color: MerchantTheme.warning,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettlementScreen()),
                    );
                    _loadData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pending settlements banner
            if (_pendingSettlements > 0) ...[
              PendingSettlementsBanner(
                count: _pendingSettlements,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettlementScreen()),
                  );
                  _loadData();
                },
              ),
              const SizedBox(height: 20),
            ],

            // Error state
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MerchantTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: MerchantTheme.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: MerchantTheme.danger, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Recent Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MerchantTheme.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransactionListScreen()),
                    );
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: MerchantTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_recentTxns.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: MerchantTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: MerchantTheme.textMuted,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No transactions yet',
                        style: TextStyle(
                          color: MerchantTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Start by making a deposit or withdrawal',
                        style: TextStyle(
                          color: MerchantTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Show last 5
              Container(
                decoration: BoxDecoration(
                  color: MerchantTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MerchantTheme.border),
                ),
                child: Column(
                  children: _recentTxns
                      .take(5)
                      .map((txn) => RecentTransactionTile(txn: txn))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Circular Button ───────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: MerchantTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
