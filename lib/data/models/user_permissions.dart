class UserPermissions {
  // Transactions
  final bool createTransaction;
  final bool viewAllTransactions;

  // Debts
  final bool viewDebts;
  final bool createDebt;
  final bool collectDebt;
  final bool deleteDebt;

  // Wallets
  final bool viewWallets;
  final bool viewWalletBalance;
  final bool createWallet;
  final bool addBalance;
  final bool editWallet;

  // Dashboard
  final bool viewDashboardStats;

  UserPermissions({
    this.createTransaction = false,
    this.viewAllTransactions = false,
    this.viewDebts = false,
    this.createDebt = false,
    this.collectDebt = false,
    this.deleteDebt = false,
    this.viewWallets = false,
    this.viewWalletBalance = false,
    this.createWallet = false,
    this.addBalance = false,
    this.editWallet = false,
    this.viewDashboardStats = false,
  });

  factory UserPermissions.defaultPermissions() {
    return UserPermissions(
      createTransaction: false,
      viewAllTransactions: false,
      viewDebts: false,
      createDebt: false,
      collectDebt: false,
      deleteDebt: false,
      viewWallets: false,
      viewWalletBalance: false,
      createWallet: false,
      addBalance: false,
      editWallet: false,
      viewDashboardStats: false,
    );
  }

  factory UserPermissions.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return UserPermissions.defaultPermissions();
    }

    // Handling backward compatibility
    // Old fields: canCreateTransactions, canCreateDebt, canViewAllTransactions, canMarkDebtPaid
    // Old screens list: canAccessScreens

    // Check if we are migrating from old structure (i.e. if new keys are missing but old ones might exist)
    // Actually, checking specific keys is safer.

    final bool hasNewKeys =
        map.containsKey('createTransaction') || map.containsKey('viewDebts');

    if (!hasNewKeys) {
      // Attempt legacy mapping
      final oldCreateTx = map['canCreateTransactions'] as bool? ?? true;
      final oldCreateDebt = map['canCreateDebt'] as bool? ?? true;
      final oldMarkPaid = map['canMarkDebtPaid'] as bool? ?? true;
      final oldViewAllTx = map['canViewAllTransactions'] as bool? ?? false;

      final screens = (map['canAccessScreens'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          {};

      return UserPermissions(
        createTransaction: oldCreateTx,
        viewAllTransactions: oldViewAllTx,

        viewDebts:
            screens.contains('DebtsListScreen') || oldCreateDebt || oldMarkPaid,
        createDebt: oldCreateDebt,
        collectDebt: oldMarkPaid,
        deleteDebt: false, // Safer default

        viewWallets:
            true, // Basic view usually allowed if not restricted before
        viewWalletBalance: false,
        createWallet: false,
        addBalance:
            false, // Old system didn't explicitly block this but UI might have
        editWallet: false,

        viewDashboardStats: screens.contains('DashboardScreen'),
      );
    }

    return UserPermissions(
      createTransaction: map['createTransaction'] ?? false,
      viewAllTransactions: map['viewAllTransactions'] ?? false,
      viewDebts: map['viewDebts'] ?? false,
      createDebt: map['createDebt'] ?? false,
      collectDebt: map['collectDebt'] ?? false,
      deleteDebt: map['deleteDebt'] ?? false,
      viewWallets: map['viewWallets'] ?? false,
      viewWalletBalance: map['viewWalletBalance'] ?? false,
      createWallet: map['createWallet'] ?? false,
      addBalance: map['addBalance'] ?? false,
      editWallet: map['editWallet'] ?? false,
      viewDashboardStats: map['viewDashboardStats'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createTransaction': createTransaction,
      'viewAllTransactions': viewAllTransactions,
      'viewDebts': viewDebts,
      'createDebt': createDebt,
      'collectDebt': collectDebt,
      'deleteDebt': deleteDebt,
      'viewWallets': viewWallets,
      'viewWalletBalance': viewWalletBalance,
      'createWallet': createWallet,
      'addBalance': addBalance,
      'editWallet': editWallet,
      'viewDashboardStats': viewDashboardStats,
    };
  }

  UserPermissions copyWith({
    bool? createTransaction,
    bool? viewAllTransactions,
    bool? viewDebts,
    bool? createDebt,
    bool? collectDebt,
    bool? deleteDebt,
    bool? viewWallets,
    bool? viewWalletBalance,
    bool? createWallet,
    bool? addBalance,
    bool? editWallet,
    bool? viewDashboardStats,
  }) {
    return UserPermissions(
      createTransaction: createTransaction ?? this.createTransaction,
      viewAllTransactions: viewAllTransactions ?? this.viewAllTransactions,
      viewDebts: viewDebts ?? this.viewDebts,
      createDebt: createDebt ?? this.createDebt,
      collectDebt: collectDebt ?? this.collectDebt,
      deleteDebt: deleteDebt ?? this.deleteDebt,
      viewWallets: viewWallets ?? this.viewWallets,
      viewWalletBalance: viewWalletBalance ?? this.viewWalletBalance,
      createWallet: createWallet ?? this.createWallet,
      addBalance: addBalance ?? this.addBalance,
      editWallet: editWallet ?? this.editWallet,
      viewDashboardStats: viewDashboardStats ?? this.viewDashboardStats,
    );
  }
}
