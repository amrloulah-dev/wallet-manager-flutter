class FirebaseConstants {
  // Collections
  static const String storesCollection = 'stores';
  static const String usersCollection = 'users';
  static const String walletsCollection = 'wallets';
  static const String transactions = 'transactions';
  static const String debts = 'debts';
  static const String dailyStatsCollection = 'daily_stats';
  static const String deviceRegistrationsCollection = 'device_registrations';
  static const String subscriptionRequestsCollection = 'subscription_requests';
  static const String statsCollection = 'stats';
  static const String summaryDoc = 'summary';
  static const String systemConfigsCollection = 'system_configs';
  static const String defaultConfigDoc = 'default';
  static const String licenseKeysCollection = 'license_keys';
  static const String pinLocksCollection = 'pin_locks';

  // Common
  static const String storeId = 'storeId';
  static const String userId = 'userId';
  static const String createdAt = 'createdAt';
  static const String createdBy = 'createdBy';
  static const String updatedAt = 'updatedAt';
  static const String isActive = 'isActive';
  static const String notes = 'notes';
  static const String firstSeenAt = 'firstSeenAt';
  static const String lastSeenAt = 'lastSeenAt';

  // Store
  static const String ownerIdField = 'ownerId';
  static const String ownerName = 'ownerName';
  static const String ownerEmail = 'ownerEmail';
  static const String ownerPhoto = 'ownerPhoto';
  static const String storePassword = 'storePassword';

  // User
  static const String firebaseUidField = 'firebaseUid';
  static const String role = 'role';
  static const String ownerRole = 'owner';
  static const String employeeRole = 'employee';
  static const String fullName = 'fullName';
  static const String pin = 'pin';
  static const String permissions = 'permissions';
  static const String lastLogin = 'lastLogin';

  // Wallet
  static const String walletId = 'walletId';
  static const String phoneNumber = 'phoneNumber';
  static const String walletType = 'walletType';
  static const String walletStatus = 'walletStatus';
  static const String sendLimits = 'sendLimits';
  static const String receiveLimits = 'receiveLimits';
  static const String lastDailyReset = 'lastDailyReset';
  static const String lastMonthlyReset = 'lastMonthlyReset';

  // License
  static const String licenseStatus = 'license.status';
  static const String licenseLastCheck = 'license.lastCheck';

  // Stats
  static const String stats = 'stats';
  static const String statsLastUpdated = 'stats.lastUpdated';
  static const String totalTransactions = 'totalTransactions';
  static const String totalSentAmount = 'totalSentAmount';
  static const String totalReceivedAmount = 'totalReceivedAmount';
  static const String lastTransactionDate = 'lastTransactionDate';
  static const String totalWallets = 'totalWallets';
  static const String activeWallets = 'activeWallets';
  static const String totalBalance = 'totalBalance';
  static const String totalTransactionsToday = 'totalTransactionsToday';
  static const String totalCommissionToday = 'totalCommissionToday';
  static const String totalServiceFeeToday = 'totalServiceFeeToday';
  static const String totalSentAmountToday = 'totalSentAmountToday';
  static const String totalReceivedAmountToday = 'totalReceivedAmountToday';
  static const String totalCommission = 'totalCommission';
  static const String totalServiceFee = 'totalServiceFee';
  static const String totalDebtsCreated = 'totalDebtsCreated';

  // Path Builders
  static String storePath(String storeId) => '$storesCollection/$storeId';

  static String statsSubcollection(String storeId) =>
      '${storePath(storeId)}/$statsCollection';

  static String statsSummaryPath(String storeId) =>
      '${statsSubcollection(storeId)}/$summaryDoc';

  static String globalStatsPath() => 'stats/global';

  static String dailyStatsSubcollection(String storeId) =>
      '${storePath(storeId)}/$dailyStatsCollection';

  static String dailyStatsPath(String storeId, String date) =>
      '${dailyStatsSubcollection(storeId)}/$date';

  static String deviceRegistrationsSubcollection(String storeId) =>
      '${storePath(storeId)}/$deviceRegistrationsCollection';

  static String deviceRegistrationPath(String storeId, String deviceId) =>
      '${deviceRegistrationsSubcollection(storeId)}/$deviceId';

  static String hardwareDeviceRegistrationPath(String deviceId) =>
      '$deviceRegistrationsCollection/$deviceId';

  static String pinLocksSubcollection(String storeId) =>
      '${storePath(storeId)}/$pinLocksCollection';

  static String pinLockPath(String storeId, String hashedPin) =>
      '${pinLocksSubcollection(storeId)}/${Uri.encodeComponent(hashedPin)}';
}
