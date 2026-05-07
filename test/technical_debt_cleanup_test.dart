import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockCacheManager extends Mock implements CacheManager {}

class MockStatsRepository extends Mock implements StatsRepository {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockFirebaseAuth mockAuth;
  late MockCollectionReference mockCollection;
  late MockCacheManager mockCacheManager;
  late MockStatsRepository mockStatsRepository;
  late MockDocumentReference mockDocRef;

  setUpAll(() {
    mockFirestore = MockFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockAuth = MockFirebaseAuth();
    mockCollection = MockCollectionReference();
    mockCacheManager = MockCacheManager();
    mockStatsRepository = MockStatsRepository();
    mockDocRef = MockDocumentReference();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockDocRef.id).thenReturn('mock_id');

    // Setup GetIt
    sl.allowReassignment = true;
    sl.registerSingleton<FirebaseFirestore>(mockFirestore);
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    sl.registerSingleton<FirebaseAuth>(mockAuth);
    sl.registerSingleton<CacheManager>(mockCacheManager);
    sl.registerSingleton<StatsRepository>(mockStatsRepository);
  });

  setUp(() {
    clearInteractions(mockFirebaseService);
    clearInteractions(mockFirestore);
    clearInteractions(mockAuth);
  });

  group('Technical Debt - Dependency Injection', () {
    test('EmployeeRepository should use sl<FirebaseService>().firestore', () {
      final repository = EmployeeRepository();
      // EmployeeRepository accesses firestore in constructor
      verify(() => mockFirebaseService.firestore).called(greaterThan(0));
    });

    test('TransactionRepository should use sl<FirebaseService>()', () {
      final repository = TransactionRepository();
      repository.generateId(); // Accesses _firestore
      verify(() => mockFirebaseService.firestore).called(greaterThan(0));
    });

    test(
        'SubscriptionRepository should use sl<FirebaseService>() for firestore',
        () async {
      final repository = SubscriptionRepository();

      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() =>
              mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      await repository
          .getLatestSubscriptionRequest('store123'); // Accesses _firestore
      verify(() => mockFirebaseService.firestore).called(greaterThan(0));
    });
  });

  group('Technical Debt - Path Builders', () {
    test('FirebaseConstants should have path builders for stats summary', () {
      expect(FirebaseConstants.statsSummaryPath('store123'),
          'stores/store123/stats/summary');
    });

    test('FirebaseConstants should have path builders for daily stats', () {
      expect(FirebaseConstants.dailyStatsPath('store123', '2026-05-01'),
          'stores/store123/daily_stats/2026-05-01');
    });

    test('FirebaseConstants should have path builders for device registrations',
        () {
      expect(FirebaseConstants.deviceRegistrationPath('store123', 'dev456'),
          'stores/store123/device_registrations/dev456');
    });

    test('FirebaseConstants should have path builders for hardware anti-fraud',
        () {
      expect(FirebaseConstants.hardwareDeviceRegistrationPath('dev456'),
          'device_registrations/dev456');
    });
  });
}
