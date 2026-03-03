import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';

/// A search field that lets agents find a customer by name or phone number.
/// When a customer is tapped, [onCustomerSelected] is called with the
/// customer object. The field shows a compact chip with the customer's
/// name and a clear button to start over.
class CustomerSearchField extends StatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer?> onCustomerSelected;

  const CustomerSearchField({
    super.key,
    this.selectedCustomer,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerSearchField> createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<Customer> _results = [];
  bool _loading = false;
  bool _showDropdown = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    final api = context.read<AuthProvider>().api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final customers = await api.searchCustomers(query);
      if (mounted) {
        setState(() {
          _results = customers;
          _showDropdown = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectCustomer(Customer customer) {
    widget.onCustomerSelected(customer);
    _searchCtrl.clear();
    _focusNode.unfocus();
    setState(() {
      _results = [];
      _showDropdown = false;
    });
  }

  void _clearCustomer() {
    widget.onCustomerSelected(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // If a customer is already selected, show a compact chip
    if (widget.selectedCustomer != null) {
      return _buildSelectedChip(widget.selectedCustomer!);
    }

    // Otherwise show the search input with dropdown
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Search Customer *',
            hintText: 'Type name or phone...',
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _results = [];
                            _showDropdown = false;
                          });
                        },
                      )
                    : null,
          ),
          onChanged: _onSearchChanged,
          validator: (_) =>
              widget.selectedCustomer == null ? 'Select a customer' : null,
        ),
        if (_showDropdown && _results.isNotEmpty) _buildResultsList(),
        if (_showDropdown && _results.isEmpty && !_loading)
          _buildNoResults(),
      ],
    );
  }

  Widget _buildSelectedChip(Customer cust) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MerchantTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MerchantTheme.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MerchantTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                cust.initials,
                style: const TextStyle(
                  color: MerchantTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cust.fullName,
                  style: const TextStyle(
                    color: MerchantTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cust.phone,
                  style: const TextStyle(
                    color: MerchantTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // KYC badge
          _kycBadge(cust.kycStatus),
          const SizedBox(width: 8),
          // Clear button
          InkWell(
            onTap: _clearCustomer,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: MerchantTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: MerchantTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MerchantTheme.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _results.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: MerchantTheme.border),
        itemBuilder: (ctx, i) {
          final cust = _results[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: MerchantTheme.primary.withValues(alpha: 0.15),
              child: Text(
                cust.initials,
                style: const TextStyle(
                  color: MerchantTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              cust.fullName,
              style: const TextStyle(
                color: MerchantTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              cust.phone,
              style: const TextStyle(
                color: MerchantTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: _kycBadge(cust.kycStatus),
            onTap: () => _selectCustomer(cust),
          );
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: MerchantTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MerchantTheme.border),
      ),
      child: const Center(
        child: Text(
          'No customers found',
          style: TextStyle(color: MerchantTheme.textMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _kycBadge(String kycStatus) {
    final Color bg;
    final Color fg;
    switch (kycStatus) {
      case 'verified':
        bg = const Color(0xFF064E3B).withValues(alpha: 0.6);
        fg = const Color(0xFF34D399);
        break;
      case 'rejected':
        bg = const Color(0xFF7F1D1D).withValues(alpha: 0.6);
        fg = const Color(0xFFF87171);
        break;
      default:
        bg = const Color(0xFF78350F).withValues(alpha: 0.6);
        fg = const Color(0xFFFBBF24);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        kycStatus.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
