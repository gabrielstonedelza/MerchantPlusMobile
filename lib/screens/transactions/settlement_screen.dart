import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../models/transaction.dart';
import 'deposit_screen.dart';
import 'withdrawal_screen.dart';

/// Screen showing approved requests ready for settlement by the agent.
/// Tapping a request navigates to the appropriate pre-filled form.
class SettlementScreen extends StatefulWidget {
  /// When true, skips Scaffold/AppBar so it can live inside MainShell.
  final bool embeddedMode;

  const SettlementScreen({super.key, this.embeddedMode = false});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  List<Transaction> _requests = [];
  bool _loading = true;
  String _filter = 'all'; // all | deposit | withdrawal

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final data = await api.getPendingSettlements();
      if (mounted) setState(() => _requests = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: MerchantTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Transaction> get _filtered {
    if (_filter == 'all') return _requests;
    return _requests.where((t) => t.transactionType == _filter).toList();
  }

  /// Navigate to the appropriate pre-filled form based on channel + type.
  Future<void> _navigateToSettleForm(Transaction tx) async {
    Widget screen;

    if (tx.isDeposit) {
      // Bank deposit → DepositScreen tab 0, MoMo deposit → tab 1
      screen = DepositScreen(
        settleRequest: tx,
        initialTab: tx.isBankChannel ? 0 : 1,
      );
    } else {
      // Bank withdrawal → WithdrawalScreen tab 0, MoMo withdrawal → tab 1
      screen = WithdrawalScreen(
        settleRequest: tx,
        initialTab: tx.isBankChannel ? 0 : 1,
      );
    }

    final settled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    // If the request was settled, refresh the list
    if (settled == true && mounted) {
      _load();
    }
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Deposits',
                selected: _filter == 'deposit',
                onTap: () => setState(() => _filter = 'deposit'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Withdrawals',
                selected: _filter == 'withdrawal',
                onTap: () => setState(() => _filter = 'withdrawal'),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 48,
                                      color: MerchantTheme.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'No pending settlements',
                                    style: TextStyle(
                                        color: MerchantTheme.textSecondary,
                                        fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'All approved requests have been settled',
                                    style: TextStyle(
                                        color: MerchantTheme.textSecondary,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _SettlementTile(
                            tx: _filtered[i],
                            onTap: () =>
                                _navigateToSettleForm(_filtered[i]),
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedMode) {
      return SafeArea(child: _buildBody());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Requests')),
      body: _buildBody(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MerchantTheme.primary : MerchantTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? MerchantTheme.primary : MerchantTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : MerchantTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;

  const _SettlementTile({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDeposit = tx.isDeposit;
    final amount = double.tryParse(tx.amount)?.toStringAsFixed(2) ?? tx.amount;

    return Card(
      color: MerchantTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MerchantTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDeposit
                      ? MerchantTheme.accent.withValues(alpha: 0.15)
                      : MerchantTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isDeposit ? MerchantTheme.accent : MerchantTheme.warning,
                  size: 22,
                ),
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
                    const SizedBox(height: 4),
                    Text(
                      '${tx.transactionType.toUpperCase()} \u00b7 ${tx.providerDisplayName} \u00b7 ${tx.reference}',
                      style: const TextStyle(
                        color: MerchantTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount + settle button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵ $amount',
                    style: TextStyle(
                      color: isDeposit ? MerchantTheme.accent : MerchantTheme.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MerchantTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
