import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/customer.dart';
import '../../models/customer_account.dart';
import '../../models/transaction.dart';
import '../../widgets/customer_search_field.dart';
import '../../widgets/add_account_sheet.dart';

class DepositScreen extends StatefulWidget {
  /// When non-null, the screen operates in "settle" mode:
  /// fields are pre-filled & read-only, submit calls settleRequest().
  final Transaction? settleRequest;

  /// Which tab to show initially (0 = Bank, 1 = MoMo).
  final int initialTab;

  const DepositScreen({
    super.key,
    this.settleRequest,
    this.initialTab = 0,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  bool get _isSettleMode => widget.settleRequest != null;

  // Selected customer (shared across all tabs)
  Customer? _selectedCustomer;

  // Customer accounts (loaded after a customer is selected)
  List<CustomerAccount> _bankAccounts = [];
  List<CustomerAccount> _momoAccounts = [];
  bool _loadingAccounts = false;
  String? _accountsError;
  CustomerAccount? _selectedBankAccount;
  CustomerAccount? _selectedMomoAccount;

  // Common
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Bank fields
  final _bankNameCtrl = TextEditingController();
  final _accountNumCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();

  // MoMo fields
  String _momoNetwork = 'mtn';
  final _senderCtrl = TextEditingController();
  final _momoRefCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    // Pre-fill fields when settling an approved request
    final sr = widget.settleRequest;
    if (sr != null) {
      _amountCtrl.text =
          (double.tryParse(sr.amount) ?? 0).toStringAsFixed(2);

      if (sr.isBankChannel && sr.bankTransactionDetail != null) {
        final bd = sr.bankTransactionDetail!;
        _bankNameCtrl.text = bd.bankName;
        _accountNumCtrl.text = bd.accountNumber;
        _accountNameCtrl.text = bd.accountName;
        _customerNameCtrl.text = bd.customerName;
      } else if (sr.isMoMoChannel && sr.momoDetail != null) {
        final md = sr.momoDetail!;
        _momoNetwork = md.network.isNotEmpty ? md.network : 'mtn';
        _senderCtrl.text = md.senderNumber;
        _momoRefCtrl.text = md.momoReference;
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumCtrl.dispose();
    _accountNameCtrl.dispose();
    _customerNameCtrl.dispose();
    _senderCtrl.dispose();
    _momoRefCtrl.dispose();
    super.dispose();
  }

  void _onCustomerSelected(Customer? customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedBankAccount = null;
      _selectedMomoAccount = null;
      _bankAccounts = [];
      _momoAccounts = [];
      _accountsError = null;
      // Clear form fields
      _bankNameCtrl.clear();
      _accountNumCtrl.clear();
      _accountNameCtrl.clear();
      _senderCtrl.clear();
    });
    if (customer != null) {
      _customerNameCtrl.text = customer.fullName;
      _fetchCustomerAccounts(customer.id);
    }
  }

  Future<void> _fetchCustomerAccounts(String customerId) async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
    });
    try {
      debugPrint('[DepositScreen] Fetching accounts for customer: $customerId');
      final accounts = await api.getCustomerAccounts(customerId);
      debugPrint('[DepositScreen] Got ${accounts.length} accounts');
      for (final a in accounts) {
        debugPrint('[DepositScreen]   -> ${a.accountType}: ${a.displayLabel}');
      }
      if (mounted) {
        setState(() {
          _bankAccounts =
              accounts.where((a) => a.isBank).toList();
          _momoAccounts =
              accounts.where((a) => a.isMobileMoney).toList();
          _loadingAccounts = false;
        });
      }
    } catch (e) {
      debugPrint('[DepositScreen] Error fetching accounts: $e');
      if (mounted) {
        setState(() {
          _loadingAccounts = false;
          _accountsError = e.toString();
        });
      }
    }
  }

  void _onBankAccountSelected(CustomerAccount? acct) {
    setState(() => _selectedBankAccount = acct);
    if (acct != null) {
      _bankNameCtrl.text = acct.bankOrNetworkDisplay;
      _accountNumCtrl.text = acct.accountNumber;
      _accountNameCtrl.text = acct.accountName;
    }
  }

  void _onMomoAccountSelected(CustomerAccount? acct) {
    setState(() => _selectedMomoAccount = acct);
    if (acct != null) {
      _momoNetwork = acct.mobileNetwork.isNotEmpty
          ? acct.mobileNetwork
          : networkKey(acct.bankOrNetworkDisplay);
      _senderCtrl.text = acct.accountNumber;
    }
  }

  Future<void> _addBankAccount() async {
    if (_selectedCustomer == null) return;
    final newAccount = await AddAccountSheet.show(
      context,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.fullName,
      accountType: 'bank',
    );
    if (newAccount != null && mounted) {
      setState(() {
        _bankAccounts.add(newAccount);
        _selectedBankAccount = newAccount;
      });
      _onBankAccountSelected(newAccount);
    }
  }

  Future<void> _addMomoAccount() async {
    if (_selectedCustomer == null) return;
    final newAccount = await AddAccountSheet.show(
      context,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.fullName,
      accountType: 'mobile_money',
    );
    if (newAccount != null && mounted) {
      setState(() {
        _momoAccounts.add(newAccount);
        _selectedMomoAccount = newAccount;
      });
      _onMomoAccountSelected(newAccount);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit handlers
  // ---------------------------------------------------------------------------
  Future<void> _submitSettle() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().api!.settleRequest(
            widget.settleRequest!.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit settled successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: MerchantTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitBankDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().api!.createBankTransaction(
            transactionType: 'deposit',
            amount: double.parse(_amountCtrl.text.trim()),
            bankName: _bankNameCtrl.text.trim(),
            accountNumber: _accountNumCtrl.text.trim(),
            accountName: _accountNameCtrl.text.trim(),
            customerName: _customerNameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            customerId: _selectedCustomer?.id,
            bank: _selectedBankAccount != null && _selectedBankAccount!.bank.isNotEmpty
                ? _selectedBankAccount!.bank
                : bankKey(_bankNameCtrl.text.trim()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank deposit recorded')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: MerchantTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitMomoDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().api!.createMomoTransaction(
            transactionType: 'deposit',
            amount: double.parse(_amountCtrl.text.trim()),
            network: _momoNetwork,
            serviceType: 'cash_in',
            senderNumber: _senderCtrl.text.trim(),
            momoReference: _momoRefCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            customerId: _selectedCustomer?.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mobile Money deposit recorded')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: MerchantTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSettleMode ? 'Settle Deposit' : 'New Deposit'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance), text: 'Bank'),
            Tab(icon: Icon(Icons.phone_android), text: 'MoMo'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildBankForm(),
            _buildMomoForm(),
          ],
        ),
      ),
    );
  }

  Widget _customerSearch() => CustomerSearchField(
        selectedCustomer: _selectedCustomer,
        onCustomerSelected: _onCustomerSelected,
      );

  // ---------------------------------------------------------------------------
  // Account selector widgets
  // ---------------------------------------------------------------------------
  Widget _bankAccountSelector() {
    if (_selectedCustomer == null) return const SizedBox.shrink();
    if (_loadingAccounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_accountsError != null) {
      return _accountsErrorWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bankAccounts.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedBankAccount?.id,
            decoration: const InputDecoration(
              labelText: 'Select Bank Account *',
              prefixIcon: Icon(Icons.account_balance),
            ),
            items: _bankAccounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.displayLabel),
                    ))
                .toList(),
            onChanged: (id) {
              final acct = _bankAccounts.firstWhere((a) => a.id == id);
              _onBankAccountSelected(acct);
            },
            validator: (v) =>
                v == null ? 'Select a bank account' : null,
          ),
          const SizedBox(height: 8),
        ],
        if (_bankAccounts.isEmpty)
          _noAccountsMessage('bank'),
        _addAccountButton(
          label: _bankAccounts.isEmpty
              ? 'Register Bank Account'
              : 'Add Another Bank Account',
          onTap: _addBankAccount,
        ),
      ],
    );
  }

  Widget _momoAccountSelector() {
    if (_selectedCustomer == null) return const SizedBox.shrink();
    if (_loadingAccounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_accountsError != null) {
      return _accountsErrorWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_momoAccounts.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedMomoAccount?.id,
            decoration: const InputDecoration(
              labelText: 'Select MoMo Account *',
              prefixIcon: Icon(Icons.phone_android),
            ),
            items: _momoAccounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.displayLabel),
                    ))
                .toList(),
            onChanged: (id) {
              final acct = _momoAccounts.firstWhere((a) => a.id == id);
              _onMomoAccountSelected(acct);
            },
            validator: (v) =>
                v == null ? 'Select a MoMo account' : null,
          ),
          const SizedBox(height: 8),
        ],
        if (_momoAccounts.isEmpty)
          _noAccountsMessage('mobile money'),
        _addAccountButton(
          label: _momoAccounts.isEmpty
              ? 'Register MoMo Account'
              : 'Add Another MoMo Account',
          onTap: _addMomoAccount,
        ),
      ],
    );
  }

  Widget _accountsErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MerchantTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MerchantTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: MerchantTheme.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to load accounts: $_accountsError',
                  style: const TextStyle(
                      color: MerchantTheme.danger, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (_selectedCustomer != null) {
                _fetchCustomerAccounts(_selectedCustomer!.id);
              }
            },
            child: const Text(
              'Tap to retry',
              style: TextStyle(
                color: MerchantTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noAccountsMessage(String type) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MerchantTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MerchantTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: MerchantTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No $type accounts registered. Please register one to continue.',
              style: const TextStyle(
                  color: MerchantTheme.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addAccountButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: MerchantTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form tabs
  // ---------------------------------------------------------------------------
  Widget _buildBankForm() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isSettleMode) ...[
            _customerSearch(),
            const SizedBox(height: 16),
            _bankAccountSelector(),
            const SizedBox(height: 16),
          ],
          _amountField(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bankNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Bank Name *',
              prefixIcon: Icon(Icons.account_balance),
            ),
            readOnly: _isSettleMode || _selectedBankAccount != null,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNumCtrl,
            decoration: const InputDecoration(
              labelText: 'Account Number *',
              prefixIcon: Icon(Icons.tag),
            ),
            readOnly: _isSettleMode || _selectedBankAccount != null,
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Account Name *',
              prefixIcon: Icon(Icons.person),
            ),
            readOnly: _isSettleMode || _selectedBankAccount != null,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _customerNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer Name *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            readOnly: _isSettleMode,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          if (!_isSettleMode) ...[
            const SizedBox(height: 16),
            _descriptionField(),
          ],
          const SizedBox(height: 24),
          _submitButton(
            _isSettleMode ? 'Settle Deposit' : 'Record Bank Deposit',
            _isSettleMode ? _submitSettle : _submitBankDeposit,
          ),
        ],
      ),
    );
  }

  Widget _buildMomoForm() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isSettleMode) ...[
            _customerSearch(),
            const SizedBox(height: 16),
            _momoAccountSelector(),
            const SizedBox(height: 16),
          ],
          _amountField(),
          const SizedBox(height: 16),
          // Network is auto-filled from selected account but can be overridden
          DropdownButtonFormField<String>(
            initialValue: _momoNetwork,
            decoration: const InputDecoration(
              labelText: 'Network *',
              prefixIcon: Icon(Icons.cell_tower),
            ),
            items: const [
              DropdownMenuItem(value: 'mtn', child: Text('MTN')),
              DropdownMenuItem(value: 'vodafone', child: Text('Vodafone')),
              DropdownMenuItem(value: 'airteltigo', child: Text('AirtelTigo')),
            ],
            onChanged: _isSettleMode
                ? null
                : (v) => setState(() => _momoNetwork = v ?? 'mtn'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _senderCtrl,
            decoration: const InputDecoration(
              labelText: 'Sender Number *',
              prefixIcon: Icon(Icons.phone),
              hintText: '0XX XXX XXXX',
            ),
            readOnly: _isSettleMode || _selectedMomoAccount != null,
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _momoRefCtrl,
            decoration: const InputDecoration(
              labelText: 'MoMo Reference (optional)',
              prefixIcon: Icon(Icons.tag),
            ),
            readOnly: _isSettleMode,
          ),
          if (!_isSettleMode) ...[
            const SizedBox(height: 16),
            _descriptionField(),
          ],
          const SizedBox(height: 24),
          _submitButton(
            _isSettleMode ? 'Settle Deposit' : 'Record MoMo Deposit',
            _isSettleMode ? _submitSettle : _submitMomoDeposit,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared form fields
  // ---------------------------------------------------------------------------
  Widget _amountField() => TextFormField(
        controller: _amountCtrl,
        decoration: const InputDecoration(
          labelText: 'Amount (GH₵) *',
          prefixIcon: Icon(Icons.attach_money),
        ),
        readOnly: _isSettleMode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Amount is required';
          final num = double.tryParse(v);
          if (num == null || num <= 0) return 'Enter a valid positive amount';
          return null;
        },
      );

  Widget _descriptionField() => TextFormField(
        controller: _descCtrl,
        decoration: const InputDecoration(
          labelText: 'Description (optional)',
          prefixIcon: Icon(Icons.notes),
        ),
        maxLines: 2,
      );

  Widget _submitButton(String label, VoidCallback onPressed) =>
      ElevatedButton(
        onPressed: _loading ? null : onPressed,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      );
}
