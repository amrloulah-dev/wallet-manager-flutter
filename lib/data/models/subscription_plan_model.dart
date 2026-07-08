import '../../core/utils/number_parser.dart';

class SubscriptionPlanModel {
  final String name;
  final String description;
  final bool isActive;
  final num price;
  final int maxWallets;
  final int maxEmployees;
  final bool smsEnabled;

  const SubscriptionPlanModel({
    required this.name,
    required this.description,
    required this.isActive,
    required this.price,
    required this.maxWallets,
    required this.maxEmployees,
    required this.smsEnabled,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const SubscriptionPlanModel(
        name: '',
        description: '',
        isActive: false,
        price: 0.0,
        maxWallets: 0,
        maxEmployees: 0,
        smsEnabled: false,
      );
    }

    return SubscriptionPlanModel(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      price: map['price'] is num ? (map['price'] as num) : NumberParser.toDouble(map['price'], 0.0),
      maxWallets: NumberParser.toInt(map['maxWallets'], 0),
      maxEmployees: NumberParser.toInt(map['maxEmployees'], 0),
      smsEnabled: map['smsEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'isActive': isActive,
      'price': price,
      'maxWallets': maxWallets,
      'maxEmployees': maxEmployees,
      'smsEnabled': smsEnabled,
    };
  }
}
