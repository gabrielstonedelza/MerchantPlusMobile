import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/customer.dart';
import '../models/customer_account.dart';
import '../models/transaction.dart';
import '../models/provider_balance.dart';
import '../models/app_notification.dart';

class ApiService {
  final String token;
  final String companyId;

  ApiService({required this.token, required this.companyId});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
        'X-Company-ID': companyId,
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  // ---------------------------------------------------------------------------
  // Customers
  // ---------------------------------------------------------------------------
  Future<List<Customer>> getCustomers({String? search}) async {
    var url = ApiConfig.customersUrl;
    if (search != null && search.isNotEmpty) {
      url += '?search=$search';
    }
    final resp = await http.get(_uri(url), headers: _headers);
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => Customer.fromJson(j)).toList();
  }

  Future<Customer> createCustomer({
    required String fullName,
    required String phone,
    String email = '',
    String address = '',
    String city = '',
    String idType = '',
    String idNumber = '',
    String dateOfBirth = '',
    String digitalAddress = '',
    File? idDocumentFront,
    File? idDocumentBack,
    File? photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri(ApiConfig.customersUrl),
    );

    // Auth headers (skip Content-Type — MultipartRequest sets its own)
    request.headers['Authorization'] = 'Token $token';
    request.headers['X-Company-ID'] = companyId;

    // Required fields
    request.fields['full_name'] = fullName;
    request.fields['phone'] = phone;

    // Optional text fields
    if (email.isNotEmpty) request.fields['email'] = email;
    if (address.isNotEmpty) request.fields['address'] = address;
    if (city.isNotEmpty) request.fields['city'] = city;
    if (idType.isNotEmpty) request.fields['id_type'] = idType;
    if (idNumber.isNotEmpty) request.fields['id_number'] = idNumber;
    if (dateOfBirth.isNotEmpty) request.fields['date_of_birth'] = dateOfBirth;
    if (digitalAddress.isNotEmpty) {
      request.fields['digital_address'] = digitalAddress;
    }

    // File fields
    if (idDocumentFront != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
            'id_document_front', idDocumentFront.path),
      );
    }
    if (idDocumentBack != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
            'id_document_back', idDocumentBack.path),
      );
    }
    if (photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photo.path),
      );
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    _checkResponse(resp);
    return Customer.fromJson(jsonDecode(resp.body));
  }

  /// Search customers by name or phone (uses the /lookup/?q= endpoint).
  /// Returns up to 20 active customers matching the query.
  Future<List<Customer>> searchCustomers(String query) async {
    final url = '${ApiConfig.customerLookupUrl}?q=${Uri.encodeComponent(query)}';
    final resp = await http.get(_uri(url), headers: _headers);
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => Customer.fromJson(j)).toList();
  }

  // ---------------------------------------------------------------------------
  // Customer Accounts
  // ---------------------------------------------------------------------------
  /// Fetch all bank/mobile money accounts for a customer.
  Future<List<CustomerAccount>> getCustomerAccounts(String customerId) async {
    final resp = await http.get(
      _uri(ApiConfig.customerAccountsUrl(customerId)),
      headers: _headers,
    );
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => CustomerAccount.fromJson(j)).toList();
  }

  /// Register a new bank or mobile money account for a customer.
  Future<CustomerAccount> createCustomerAccount({
    required String customerId,
    required String accountType, // 'bank' or 'mobile_money'
    required String accountNumber,
    required String accountName,
    String bank = '', // choice key e.g. 'ecobank', 'gcb'
    String mobileNetwork = '', // choice key e.g. 'mtn', 'vodafone'
    bool isPrimary = false,
  }) async {
    final resp = await http.post(
      _uri(ApiConfig.customerAccountsUrl(customerId)),
      headers: _headers,
      body: jsonEncode({
        'account_type': accountType,
        'account_number': accountNumber,
        'account_name': accountName,
        if (bank.isNotEmpty) 'bank': bank,
        if (mobileNetwork.isNotEmpty) 'mobile_network': mobileNetwork,
        'is_primary': isPrimary,
      }),
    );
    _checkResponse(resp);
    return CustomerAccount.fromJson(jsonDecode(resp.body));
  }

  Future<void> deleteCustomer(String customerId) async {
    final resp = await http.delete(
      _uri(ApiConfig.customerDetailUrl(customerId)),
      headers: _headers,
    );
    _checkResponse(resp);
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------
  Future<List<Transaction>> getTransactions({
    String? type,
    String? status,
  }) async {
    var url = ApiConfig.transactionsUrl;
    final params = <String>[];
    if (type != null) params.add('type=$type');
    if (status != null) params.add('status=$status');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final resp = await http.get(_uri(url), headers: _headers);
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => Transaction.fromJson(j)).toList();
  }

  Future<Transaction> createBankTransaction({
    required String transactionType, // 'deposit' or 'withdrawal'
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String customerName,
    String? customerId,
    String bank = '', // bank choice key e.g. 'ecobank', 'gcb'
    String description = '',
  }) async {
    final resp = await http.post(
      _uri(ApiConfig.bankTransactionUrl),
      headers: _headers,
      body: jsonEncode({
        'transaction_type': transactionType,
        'amount': amount,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
        'customer_name': customerName,
        if (customerId != null) 'customer': customerId,
        if (bank.isNotEmpty) 'bank': bank,
        if (description.isNotEmpty) 'description': description,
      }),
    );
    _checkResponse(resp);
    return Transaction.fromJson(jsonDecode(resp.body));
  }

  Future<Transaction> createMomoTransaction({
    required String transactionType, // 'deposit' or 'withdrawal'
    required double amount,
    required String network, // 'mtn', 'vodafone', 'airteltigo'
    required String serviceType,
    String senderNumber = '',
    String? customerId,
    String receiverNumber = '',
    String momoReference = '',
    String description = '',
  }) async {
    final resp = await http.post(
      _uri(ApiConfig.momoTransactionUrl),
      headers: _headers,
      body: jsonEncode({
        'transaction_type': transactionType,
        'amount': amount,
        'network': network,
        'service_type': serviceType,
        'sender_number': senderNumber,
        if (customerId != null) 'customer': customerId,
        if (receiverNumber.isNotEmpty) 'receiver_number': receiverNumber,
        if (momoReference.isNotEmpty) 'momo_reference': momoReference,
        if (description.isNotEmpty) 'description': description,
      }),
    );
    _checkResponse(resp);
    return Transaction.fromJson(jsonDecode(resp.body));
  }

  Future<Transaction> createCashTransaction({
    required String transactionType,
    required double amount,
    String? customerId,
    String description = '',
  }) async {
    final resp = await http.post(
      _uri(ApiConfig.cashTransactionUrl),
      headers: _headers,
      body: jsonEncode({
        'transaction_type': transactionType,
        'amount': amount,
        if (customerId != null) 'customer': customerId,
        if (description.isNotEmpty) 'description': description,
      }),
    );
    _checkResponse(resp);
    return Transaction.fromJson(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------------
  // Settlement
  // ---------------------------------------------------------------------------
  /// Get approved requests awaiting settlement by the current agent.
  Future<List<Transaction>> getPendingSettlements() async {
    final resp = await http.get(
      _uri(ApiConfig.pendingSettlementsUrl),
      headers: _headers,
    );
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => Transaction.fromJson(j)).toList();
  }

  /// Settle (execute) an approved request. Adjusts provider balances.
  Future<Transaction> settleRequest(String requestId) async {
    final resp = await http.post(
      _uri(ApiConfig.settleRequestUrl(requestId)),
      headers: _headers,
    );
    _checkResponse(resp);
    return Transaction.fromJson(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------------
  // Provider Balances
  // ---------------------------------------------------------------------------
  Future<List<ProviderBalance>> getProviderBalances() async {
    final resp = await http.get(
      _uri(ApiConfig.providerBalancesUrl),
      headers: _headers,
    );
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => ProviderBalance.fromJson(j)).toList();
  }

  Future<ProviderBalance> adjustBalance({
    required String provider,
    required double amount,
    required String operation, // 'add' or 'subtract'
  }) async {
    final resp = await http.post(
      _uri(ApiConfig.adjustBalanceUrl),
      headers: _headers,
      body: jsonEncode({
        'provider': provider,
        'amount': amount,
        'operation': operation,
      }),
    );
    _checkResponse(resp);
    return ProviderBalance.fromJson(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    var url = ApiConfig.notificationsUrl;
    if (unreadOnly) url += '?unread=true';
    final resp = await http.get(_uri(url), headers: _headers);
    _checkResponse(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => AppNotification.fromJson(j)).toList();
  }

  Future<int> getUnreadCount() async {
    final resp = await http.get(_uri(ApiConfig.unreadCountUrl), headers: _headers);
    _checkResponse(resp);
    final body = jsonDecode(resp.body);
    return body['unread_count'] ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final resp = await http.post(
      _uri(ApiConfig.markReadUrl(notificationId)),
      headers: _headers,
    );
    _checkResponse(resp);
  }

  Future<void> markAllNotificationsRead() async {
    final resp = await http.post(
      _uri(ApiConfig.markAllReadUrl),
      headers: _headers,
    );
    _checkResponse(resp);
  }

  // ---------------------------------------------------------------------------
  void _checkResponse(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    String msg;
    try {
      final body = jsonDecode(resp.body);
      msg = (body['error'] ?? body['detail'] ?? 'Request failed (${resp.statusCode})').toString();
    } catch (_) {
      msg = 'Request failed (${resp.statusCode})';
    }
    throw ApiException(msg, resp.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
