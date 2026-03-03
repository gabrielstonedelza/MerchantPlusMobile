/// A customer's bank or mobile money account.
class CustomerAccount {
  final String id;
  final String customerId;
  final String? customerName;
  final String accountType; // 'bank' or 'mobile_money'
  final String accountNumber;
  final String accountName;
  final String bank; // choice key e.g. 'ecobank', 'gcb' (only for bank accounts)
  final String mobileNetwork; // choice key e.g. 'mtn', 'vodafone' (only for momo)
  final String bankOrNetworkDisplay; // human-readable e.g. 'Ecobank', 'MTN'
  final bool isPrimary;
  final bool isVerified;
  final String createdAt;

  CustomerAccount({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.accountType,
    required this.accountNumber,
    required this.accountName,
    this.bank = '',
    this.mobileNetwork = '',
    this.bankOrNetworkDisplay = '',
    this.isPrimary = false,
    this.isVerified = false,
    required this.createdAt,
  });

  factory CustomerAccount.fromJson(Map<String, dynamic> json) =>
      CustomerAccount(
        id: json['id'],
        customerId: json['customer'] ?? '',
        customerName: json['customer_name'],
        accountType: json['account_type'] ?? '',
        accountNumber: json['account_number'] ?? '',
        accountName: json['account_name'] ?? '',
        bank: json['bank'] ?? '',
        mobileNetwork: json['mobile_network'] ?? '',
        bankOrNetworkDisplay: json['bank_or_network_display'] ?? '',
        isPrimary: json['is_primary'] ?? false,
        isVerified: json['is_verified'] ?? false,
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'account_type': accountType,
        'account_number': accountNumber,
        'account_name': accountName,
        'bank': bank,
        'mobile_network': mobileNetwork,
        'is_primary': isPrimary,
      };

  bool get isBank => accountType == 'bank';
  bool get isMobileMoney => accountType == 'mobile_money';

  /// Display label for dropdowns: "Ecobank - 001234567" or "MTN - 024XXXXXXX"
  String get displayLabel => '$bankOrNetworkDisplay - $accountNumber';
}
