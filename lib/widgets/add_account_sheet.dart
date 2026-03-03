import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../models/customer_account.dart';
import '../providers/auth_provider.dart';

/// Bottom sheet that lets an agent register a new bank or mobile money account
/// for a customer. Returns the newly created [CustomerAccount] on success.
class AddAccountSheet extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String accountType; // 'bank' or 'mobile_money'

  const AddAccountSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.accountType,
  });

  /// Convenience helper – opens the sheet and returns the new account (or null).
  static Future<CustomerAccount?> show(
    BuildContext context, {
    required String customerId,
    required String customerName,
    required String accountType,
  }) {
    return showModalBottomSheet<CustomerAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MerchantTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddAccountSheet(
        customerId: customerId,
        customerName: customerName,
        accountType: accountType,
      ),
    );
  }

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  String? _selectedBankOrNetwork;

  bool get _isBank => widget.accountType == 'bank';

  static const List<String> _banks = [
    'Ecobank',
    'GCB Bank',
    'Fidelity Bank',
    'Cal Bank',
    'Stanbic Bank',
    'Absa Bank',
    'UBA',
    'Access Bank',
    'Zenith Bank',
    'Republic Bank',
    'Prudential Bank',
    'First National Bank',
    'Standard Chartered',
    'Societe Generale',
    'Bank of Africa',
    'Agricultural Dev Bank',
    'First Atlantic Bank',
    'OmniBSIC Bank',
    'National Investment Bank',
    'ARB Apex Bank',
  ];

  static const List<String> _networks = [
    'MTN',
    'Vodafone',
    'AirtelTigo',
  ];

  List<String> get _options => _isBank ? _banks : _networks;

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AuthProvider>().api;
    if (api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await api.createCustomerAccount(
        customerId: widget.customerId,
        accountType: widget.accountType,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountName: _accountNameCtrl.text.trim(),
        bank: _isBank ? bankKey(_selectedBankOrNetwork!) : '',
        mobileNetwork: !_isBank ? networkKey(_selectedBankOrNetwork!) : '',
      );
      if (mounted) Navigator.pop(context, account);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + (bottomInset > 0 ? 20 : bottomPadding + 20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MerchantTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _isBank
                  ? 'Add Bank Account'
                  : 'Add Mobile Money Account',
              style: const TextStyle(
                color: MerchantTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'For ${widget.customerName}',
              style: const TextStyle(
                color: MerchantTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Inline error message
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MerchantTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MerchantTheme.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: MerchantTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: MerchantTheme.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bank / Network dropdown
            DropdownButtonFormField<String>(
              value: _selectedBankOrNetwork,
              decoration: InputDecoration(
                labelText: _isBank ? 'Bank *' : 'Network *',
                prefixIcon: Icon(
                  _isBank ? Icons.account_balance : Icons.cell_tower,
                ),
              ),
              items: _options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedBankOrNetwork = v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Account name
            TextFormField(
              controller: _accountNameCtrl,
              decoration: InputDecoration(
                labelText: 'Account Name *',
                prefixIcon: const Icon(Icons.person),
                hintText: _isBank
                    ? 'Name on bank account'
                    : 'Name on MoMo account',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Account number / phone number
            TextFormField(
              controller: _accountNumberCtrl,
              decoration: InputDecoration(
                labelText: _isBank
                    ? 'Account Number *'
                    : 'Phone Number *',
                prefixIcon: Icon(
                  _isBank ? Icons.tag : Icons.phone,
                ),
                hintText: _isBank ? '001234567890' : '024XXXXXXX',
              ),
              keyboardType: _isBank
                  ? TextInputType.number
                  : TextInputType.phone,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isBank
                          ? 'Register Bank Account'
                          : 'Register MoMo Account',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
