import 'dart:convert';

class SimWalletConfig {
  final int simSlotIndex; // 0 for SIM1, 1 for SIM2
  final String? subscriptionId; // Android unique SIM ID (nullable)
  final String walletId; // Firestore Wallet ID
  final String walletName; // Display name
  final String serviceProvider; // e.g., 'Vodafone', 'Orange'

  const SimWalletConfig({
    required this.simSlotIndex,
    this.subscriptionId,
    required this.walletId,
    required this.walletName,
    required this.serviceProvider,
  });

  /// Creates a copy of this SimWalletConfig with the given fields replaced by the new values.
  SimWalletConfig copyWith({
    int? simSlotIndex,
    String? subscriptionId,
    String? walletId,
    String? walletName,
    String? serviceProvider,
  }) {
    return SimWalletConfig(
      simSlotIndex: simSlotIndex ?? this.simSlotIndex,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      serviceProvider: serviceProvider ?? this.serviceProvider,
    );
  }

  /// Converts the [SimWalletConfig] instance to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      'simSlotIndex': simSlotIndex,
      'subscriptionId': subscriptionId,
      'walletId': walletId,
      'walletName': walletName,
      'serviceProvider': serviceProvider,
    };
  }

  /// Creates a [SimWalletConfig] instance from a JSON map.
  factory SimWalletConfig.fromMap(Map<String, dynamic> map) {
    return SimWalletConfig(
      simSlotIndex: map['simSlotIndex'] as int,
      subscriptionId: map['subscriptionId'] as String?,
      walletId: map['walletId'] as String,
      walletName: map['walletName'] as String,
      serviceProvider: map['serviceProvider'] as String,
    );
  }

  /// Converts the [SimWalletConfig] instance to a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a [SimWalletConfig] instance from a JSON string.
  factory SimWalletConfig.fromJson(String source) =>
      SimWalletConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SimWalletConfig(simSlotIndex: $simSlotIndex, subscriptionId: $subscriptionId, walletId: $walletId, walletName: $walletName, serviceProvider: $serviceProvider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SimWalletConfig &&
        other.simSlotIndex == simSlotIndex &&
        other.subscriptionId == subscriptionId &&
        other.walletId == walletId &&
        other.walletName == walletName &&
        other.serviceProvider == serviceProvider;
  }

  @override
  int get hashCode {
    return simSlotIndex.hashCode ^
        subscriptionId.hashCode ^
        walletId.hashCode ^
        walletName.hashCode ^
        serviceProvider.hashCode;
  }
}
