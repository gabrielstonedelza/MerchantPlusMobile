class ApiConfig {
  // Change this to your backend URL
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator → localhost
  // static const String baseUrl = 'http://localhost:8000'; // iOS simulator
  static const String baseUrl = 'http://192.168.1.32:8000'; // Physical device (same WiFi)
  // static const String baseUrl = 'https://merchantplusgh.com'; // Production

  static const String apiPrefix = '/api/v1';

  // Auth
  static const String loginUrl = '$apiPrefix/auth/login/';
  static const String logoutUrl = '$apiPrefix/auth/logout/';
  static const String meUrl = '$apiPrefix/auth/me/';
  static const String twoFAVerifyUrl = '$apiPrefix/auth/2fa/verify/';

  // Customers
  static const String customersUrl = '$apiPrefix/customers/';
  static const String customerLookupUrl = '$apiPrefix/customers/lookup/';
  static String customerDetailUrl(String id) => '$apiPrefix/customers/$id/';
  static String customerAccountsUrl(String id) => '$apiPrefix/customers/$id/accounts/';
  static String customerAccountDeleteUrl(String customerId, String accountId) =>
      '$apiPrefix/customers/$customerId/accounts/$accountId/';

  // Transactions
  static const String transactionsUrl = '$apiPrefix/transactions/';
  static const String bankTransactionUrl = '$apiPrefix/transactions/bank-transaction/';
  static const String momoTransactionUrl = '$apiPrefix/transactions/mobile-money/';
  static const String cashTransactionUrl = '$apiPrefix/transactions/cash/';

  // Settlement
  static const String pendingSettlementsUrl = '$apiPrefix/transactions/settlements/pending/';
  static String settleRequestUrl(String id) => '$apiPrefix/transactions/$id/settle/';

  // Provider Balances
  static const String providerBalancesUrl = '$apiPrefix/transactions/balances/';
  static const String adjustBalanceUrl = '$apiPrefix/transactions/balances/adjust/';

  // Notifications
  static const String notificationsUrl = '$apiPrefix/notifications/';
  static const String unreadCountUrl = '$apiPrefix/notifications/unread-count/';
  static const String markAllReadUrl = '$apiPrefix/notifications/read-all/';
  static String markReadUrl(String id) => '$apiPrefix/notifications/$id/read/';
}
