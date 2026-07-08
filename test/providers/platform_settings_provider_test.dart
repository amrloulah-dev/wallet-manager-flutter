import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockLocalStorageService mockStorage;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDoc;
  late MockDocumentSnapshot mockSnapshot;

  final testJson = {
    'limits': {
      'instapay': {
        'dailyReceive': 120000.0,
        'dailySend': 120000.0,
        'maxPerTransaction': 150000.0,
        'monthlyReceive': 400000.0,
        'monthlySend': 600000.0,
      },
      'networkCommercial': {
        'dailyReceive': 200000.0,
        'dailySend': 200000.0,
        'maxPerTransaction': 90000.0,
        'monthlyReceive': 500000.0,
        'monthlySend': 500000.0,
      },
      'networkNew': {
        'dailyReceive': 10000.0,
        'dailySend': 10000.0,
        'maxPerTransaction': 15000.0,
        'monthlyReceive': 600000.0,
        'monthlySend': 75000.0,
      },
      'networkOld': {
        'dailyReceive': 60000.0,
        'dailySend': 80000.0,
        'maxPerTransaction': 80000.0,
        'monthlyReceive': 200000.0,
        'monthlySend': 250000.0,
      },
    },
    'feeLimits': {
      'networks': {
        'min': 2.0,
        'max': 20.0,
      },
      'instapay': {
        'min': 1.0,
        'max': 30.0,
      },
    },
    'serviceFees': {
      'sameNetwork': 1.5,
      'crossNetwork': 0.007,
      'instapay': 0.002,
    },
    'subscriptions': {
      'lifetimeCountLimit': 50,
      'gracePeriodHours': 48,
      'trialDays': 45,
      'plans': {}
    }
  };

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockStorage = MockLocalStorageService();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection('settings')).thenReturn(mockCollection);
    when(() => mockCollection.doc('global')).thenReturn(mockDoc);
    when(() => mockDoc.get()).thenAnswer((_) async => mockSnapshot);
  });

  group('PlatformSettingsProvider', () {
    test('initialize fetches from Firestore when cache is empty', () async {
      when(() => mockStorage.getPlatformSettingsFetchTime()).thenReturn(null);
      when(() => mockStorage.getPlatformSettingsJson()).thenReturn(null);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testJson);
      when(() => mockStorage.savePlatformSettings(any())).thenAnswer((_) async {});

      final provider = PlatformSettingsProvider(
        storage: mockStorage,
        firestore: mockFirestore,
      );

      await provider.initialize();

      expect(provider.settings.newWalletTransactionLimit, 15000.0);
      expect(provider.settings.trialDurationDays, 45);
      verify(() => mockStorage.savePlatformSettings(any())).called(1);
    });

    test('initialize loads from cache when cache is fresh (<24h)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      when(() => mockStorage.getPlatformSettingsFetchTime()).thenReturn(now - 1000);
      when(() => mockStorage.getPlatformSettingsJson()).thenReturn(json.encode(testJson));

      final provider = PlatformSettingsProvider(
        storage: mockStorage,
        firestore: mockFirestore,
      );

      await provider.initialize();

      expect(provider.settings.newWalletTransactionLimit, 15000.0);
      verifyNever(() => mockDoc.get());
    });

    test('initialize fetches from Firestore when cache is stale (>24h)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final twentyFiveHoursAgo = now - const Duration(hours: 25).inMilliseconds;

      when(() => mockStorage.getPlatformSettingsFetchTime()).thenReturn(twentyFiveHoursAgo);
      when(() => mockStorage.getPlatformSettingsJson()).thenReturn(json.encode(testJson));
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testJson);
      when(() => mockStorage.savePlatformSettings(any())).thenAnswer((_) async {});

      final provider = PlatformSettingsProvider(
        storage: mockStorage,
        firestore: mockFirestore,
      );

      await provider.initialize();

      expect(provider.settings.newWalletTransactionLimit, 15000.0);
      verify(() => mockDoc.get()).called(1);
      verify(() => mockStorage.savePlatformSettings(any())).called(1);
    });

    test('forceRefresh bypasses TTL and fetches from Firestore', () async {
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testJson);
      when(() => mockStorage.savePlatformSettings(any())).thenAnswer((_) async {});

      final provider = PlatformSettingsProvider(
        storage: mockStorage,
        firestore: mockFirestore,
      );

      await provider.forceRefresh();

      expect(provider.settings.newWalletTransactionLimit, 15000.0);
      verify(() => mockDoc.get()).called(1);
    });

    test('falls back to cache when Firestore fetch fails', () async {
      when(() => mockStorage.getPlatformSettingsFetchTime()).thenReturn(null);
      when(() => mockStorage.getPlatformSettingsJson()).thenReturn(json.encode(testJson));
      when(() => mockDoc.get()).thenThrow(FirebaseException(plugin: 'cloud_firestore', message: 'Offline'));

      final provider = PlatformSettingsProvider(
        storage: mockStorage,
        firestore: mockFirestore,
      );

      await provider.initialize();

      expect(provider.settings.newWalletTransactionLimit, 15000.0);
    });
  });
}
