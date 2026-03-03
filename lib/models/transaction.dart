// ---------------------------------------------------------------------------
// Nested detail models
// ---------------------------------------------------------------------------

class BankTransactionDetail {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String customerName;

  BankTransactionDetail({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.customerName,
  });

  factory BankTransactionDetail.fromJson(Map<String, dynamic> json) =>
      BankTransactionDetail(
        bankName: json['bank_name'] ?? '',
        accountNumber: json['account_number'] ?? '',
        accountName: json['account_name'] ?? '',
        customerName: json['customer_name'] ?? '',
      );
}

class MoMoDetail {
  final String network;
  final String serviceType;
  final String senderNumber;
  final String receiverNumber;
  final String momoReference;

  MoMoDetail({
    required this.network,
    required this.serviceType,
    required this.senderNumber,
    required this.receiverNumber,
    required this.momoReference,
  });

  factory MoMoDetail.fromJson(Map<String, dynamic> json) => MoMoDetail(
        network: json['network'] ?? '',
        serviceType: json['service_type'] ?? '',
        senderNumber: json['sender_number'] ?? '',
        receiverNumber: json['receiver_number'] ?? '',
        momoReference: json['momo_reference'] ?? '',
      );
}

// ---------------------------------------------------------------------------
// Main transaction model
// ---------------------------------------------------------------------------

class Transaction {
  final String id;
  final String reference;
  final String transactionType;
  final String channel;
  final String status;
  final String amount;
  final String fee;
  final String netAmount;
  final String currency;
  final String? customerName;
  final String? customerPhone;
  final String? requestedByName;
  final String? approvedByName;
  final String? approvedAt;
  final String? settledByName;
  final String? settledAt;
  final String? bankDisplay;
  final String? mobileNetworkDisplay;
  final String createdAt;

  // Nested details (populated for approved/completed requests)
  final BankTransactionDetail? bankTransactionDetail;
  final MoMoDetail? momoDetail;

  Transaction({
    required this.id,
    required this.reference,
    required this.transactionType,
    required this.channel,
    required this.status,
    required this.amount,
    required this.fee,
    required this.netAmount,
    this.currency = 'GHS',
    this.customerName,
    this.customerPhone,
    this.requestedByName,
    this.approvedByName,
    this.approvedAt,
    this.settledByName,
    this.settledAt,
    this.bankDisplay,
    this.mobileNetworkDisplay,
    required this.createdAt,
    this.bankTransactionDetail,
    this.momoDetail,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        reference: json['reference'] ?? '',
        transactionType: json['transaction_type'] ?? '',
        channel: json['channel'] ?? '',
        status: json['status'] ?? '',
        amount: json['amount']?.toString() ?? '0',
        fee: json['fee']?.toString() ?? '0',
        netAmount: json['net_amount']?.toString() ?? '0',
        currency: json['currency'] ?? 'GHS',
        customerName: json['customer_name'],
        customerPhone: json['customer_phone'],
        requestedByName: json['requested_by_name'],
        approvedByName: json['approved_by_name'],
        approvedAt: json['approved_at'],
        settledByName: json['settled_by_name'],
        settledAt: json['settled_at'],
        bankDisplay: json['bank_display'],
        mobileNetworkDisplay: json['mobile_network_display'],
        createdAt: json['requested_at'] ?? json['created_at'] ?? '',
        bankTransactionDetail: json['bank_transaction_detail'] != null
            ? BankTransactionDetail.fromJson(json['bank_transaction_detail'])
            : null,
        momoDetail: json['momo_detail'] != null
            ? MoMoDetail.fromJson(json['momo_detail'])
            : null,
      );

  bool get isDeposit => transactionType == 'deposit';
  bool get isWithdrawal => transactionType == 'withdrawal';
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  bool get isBankChannel => channel == 'bank';
  bool get isMoMoChannel => channel == 'mobile_money';

  /// True if this request has been approved and can be settled by the agent.
  bool get canSettle => status == 'approved';

  /// Human-readable provider name (bank or network).
  String get providerDisplayName {
    if (channel == 'bank' && bankDisplay != null && bankDisplay!.isNotEmpty) {
      return bankDisplay!;
    }
    if (channel == 'mobile_money' &&
        mobileNetworkDisplay != null &&
        mobileNetworkDisplay!.isNotEmpty) {
      return mobileNetworkDisplay!;
    }
    return channel.replaceAll('_', ' ');
  }
}
