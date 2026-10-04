# Data Model: SaaS Migration

## 1. Updated StoreModel (`StoreModel`)

The `StoreModel` is the root document in the `stores` collection. Legacy fields `license`, `activeLicenseKey`, and `licenseKeyId` will be removed.

**New Embedded Field**: `subscription` (Object)

### Subscription Object Structure
```dart
class StoreSubscription {
  final String planId; // 'free', 'trial', 'pro_yearly', 'lifetime'
  final String status; // 'active', 'suspended'
  final DateTime? endDate; // null for lifetime
  final bool trialConsumed; // true if trial was used
  final int maxWallets; // e.g., 3 or 999
  final int maxEmployees; // e.g., 1 or 999
  final bool smsEnabled;

  // Helpers
  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
}
```

*Note on Migration Default (FR-17)*:
If `subscription` is missing from the Firestore document (but `license` may be present), the `fromFirestore` factory will initialize `StoreSubscription` as `lifetime` with `trialConsumed = true`.

## 2. New Collection: Subscription Requests (`SubscriptionRequestModel`)

Path: `stores/{storeId}/subscription_requests/{requestId}`

Used to track manual payment submissions (Vodafone Cash / InstaPay) awaiting admin approval.

```dart
class SubscriptionRequestModel {
  final String id;
  final String storeId;
  final String planId; // The plan being requested
  final String paymentMethod; // 'vodafone_cash', 'instapay'
  final String receiptNumber; // Transaction ID
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final Timestamp createdAt;
  final Timestamp? processedAt;
}
```

## 3. New Collection: Device Registry (`DeviceRegistryModel`)

Path: `stores/{storeId}/device_registry/{deviceId}`

Used for anti-fraud (Trial bounding to device).

```dart
class DeviceRegistryModel {
  final String deviceId; // Local generated UUID
  final String deviceModel;
  final String osVersion;
  final Timestamp firstSeenAt;
  final Timestamp lastSeenAt;
}
```

## 4. Updates to StoreSettings (`StoreSettings`)

- Remove: `maxEmployees` from `StoreSettings` (now governed by `StoreSubscription.maxEmployees`).

## 5. System Configs (`SystemConfigsModel`)

Path: `/system_configs/global` (Singleton)

For global overrides outside the client app update lifecycle.

```dart
class SystemConfigsModel {
  final int trialDays; // Default 14
  final int gracePeriodHours; // Default 48
  final String vfCashNumber; // Manual Payment target
  final String instaPayHandle; // Manual Payment target
}
```
