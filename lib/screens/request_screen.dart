import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import 'transactions/deposit_screen.dart';
import 'transactions/withdrawal_screen.dart';

/// Combined screen for agents to create new requests and view pending/approved ones.
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  List<Transaction> _transactions = [];
  bool _loading = true;
  String? _error;
  String _tab = 'pending'; // pending | approved
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds so approved requests appear promptly
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch all transactions — we filter client-side for pending/approved
      final results = await Future.wait([
        api.getTransactions(),
        api.getPendingSettlements(),
      ]);
      if (mounted) {
        final allTxns = results[0];
        final settlements = results[1];

        // Merge: all transactions + ensure approved settlements are included
        final txnMap = <String, Transaction>{};
        for (final t in allTxns) {
          txnMap[t.id] = t;
        }
        for (final t in settlements) {
          txnMap[t.id] = t;
        }

        setState(() {
          _transactions = txnMap.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  List<Transaction> get _filteredList {
    return _transactions.where((t) => t.status == _tab).toList();
  }

  /// Navigate to settlement form for an approved request.
  Future<void> _navigateToSettleForm(Transaction tx) async {
    Widget screen;
    if (tx.isDeposit) {
      screen = DepositScreen(
        settleRequest: tx,
        initialTab: tx.isBankChannel ? 0 : 1,
      );
    } else {
      screen = WithdrawalScreen(
        settleRequest: tx,
        initialTab: tx.isBankChannel ? 0 : 1,
      );
    }

    final settled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (settled == true && mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _transactions.where((t) => t.status == 'pending').length;
    final approvedCount =
        _transactions.where((t) => t.status == 'approved').length;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Requests',
                    style: TextStyle(
                      color: MerchantTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // New request button
                _NewRequestButton(
                  onDeposit: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DepositScreen()),
                    );
                    _loadData();
                  },
                  onWithdraw: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WithdrawalScreen()),
                    );
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab selector: Pending / Approved
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _TabChip(
                  label: 'Pending',
                  count: pendingCount,
                  selected: _tab == 'pending',
                  onTap: () => setState(() => _tab = 'pending'),
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: 'Approved',
                  count: approvedCount,
                  selected: _tab == 'approved',
                  color: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _tab = 'approved'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    color: MerchantTheme.danger)),
                            TextButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _filteredList.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: MerchantTheme
                                                .surfaceElevated,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            _tab == 'pending'
                                                ? Icons.hourglass_empty
                                                : Icons
                                                    .check_circle_outline,
                                            color:
                                                MerchantTheme.textMuted,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _tab == 'pending'
                                              ? 'No pending requests'
                                              : 'No approved requests',
                                          style: const TextStyle(
                                            color: MerchantTheme
                                                .textSecondary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _tab == 'pending'
                                              ? 'Create a new deposit or withdrawal request'
                                              : 'Approved requests will appear here',
                                          style: const TextStyle(
                                            color:
                                                MerchantTheme.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: _filteredList.length,
                                itemBuilder: (_, i) {
                                  final tx = _filteredList[i];
                                  return _RequestTile(
                                    tx: tx,
                                    onTap: tx.status == 'approved'
                                        ? () =>
                                            _navigateToSettleForm(tx)
                                        : null,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── New Request Button (dropdown with Deposit / Withdrawal) ─────────────────

class _NewRequestButton extends StatelessWidget {
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _NewRequestButton({
    required this.onDeposit,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'deposit') onDeposit();
        if (value == 'withdraw') onWithdraw();
      },
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: MerchantTheme.surfaceElevated,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'deposit',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MerchantTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_downward_rounded,
                    color: MerchantTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('New Deposit',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'withdraw',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MerchantTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: MerchantTheme.danger, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('New Withdrawal',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: MerchantTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                color: MerchantTheme.background, size: 20),
            SizedBox(width: 6),
            Text(
              'New Request',
              style: TextStyle(
                color: MerchantTheme.background,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Chip ────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? MerchantTheme.warning;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.15)
              : MerchantTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? chipColor.withValues(alpha: 0.4)
                : MerchantTheme.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? chipColor : MerchantTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: selected ? 0.25 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Request Tile ────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback? onTap;

  const _RequestTile({required this.tx, this.onTap});

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
    final isDeposit = tx.isDeposit;
    final color = isDeposit ? MerchantTheme.accent : MerchantTheme.danger;
    final icon = isDeposit ? Icons.arrow_downward : Icons.arrow_upward;
    final amount =
        double.tryParse(tx.amount)?.toStringAsFixed(2) ?? tx.amount;
    final isApproved = tx.status == 'approved';

    return Card(
      color: MerchantTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isApproved
              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
              : MerchantTheme.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.customerName ?? 'Unknown Customer',
                      style: const TextStyle(
                        color: MerchantTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${tx.transactionType.toUpperCase()} \u00b7 ${tx.providerDisplayName}',
                          style: const TextStyle(
                            color: MerchantTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(tx.createdAt),
                          style: const TextStyle(
                            color: MerchantTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount + settle badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵ $amount',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (isApproved) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MerchantTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SETTLE',
                        style: TextStyle(
                          color: MerchantTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
