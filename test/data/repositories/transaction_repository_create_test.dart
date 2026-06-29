import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockWriteBatch extends Mock implements WriteBatch {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}
class MockCacheManager extends Mock implements CacheManager {}
class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockWriteBatch mockBatch;
  late MockFirebaseService mockFirebaseService;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockDocumentSnapshot mockWalletSnap;
  late MockStatsRepository mockStatsRepository;
  late MockPlatformSettingsProvider mockSettingsProvider;
  late MockCacheManager mockCacheManager;
  late TransactionRepository repository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(FakeDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockBatch = MockWriteBatch();
    mockFirebaseService = MockFirebaseService();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockWalletSnap = MockDocumentSnapshot();
    mockStatsRepository = MockStatsRepository();
    mockSettingsProvider = MockPlatformSettingsProvider();
    mockCacheManager = MockCacheManager();

    // Register PlatformSettingsProvider in sl for WalletModel defaults resolution
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    when(() => mockSettingsProvider.settings).thenReturn(const PlatformSettingsModel.defaults());
    sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockFirestore.doc(any())).thenReturn(mockDocRef);
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    // Stub wallet doc get
    when(() => mockDocRef.get()).thenAnswer((_) async => mockWalletSnap);
    when(() => mockWalletSnap.exists).thenReturn(true);
    when(() => mockWalletSnap.id).thenReturn('w1');
    when(() => mockWalletSnap.data()).thenReturn({
      'walletId': 'w1',
      'storeId': 'test_store',
      'phoneNumber': '01000000000',
      'walletType': 'vodafoneCash',
      'walletStatus': 'active',
      'balance': 1000.0,
      'isActive': true,
      'createdBy': 'owner1',
      'createdAt': Timestamp.now(),
      'lastDailyReset': Timestamp.now(),
      'lastMonthlyReset': Timestamp.now(),
      'sendLimits': {'dailyLimit': 60000.0, 'dailyUsed': 0.0, 'monthlyLimit': 200000.0, 'monthlyUsed': 0.0},
      'receiveLimits': {'dailyLimit': 60000.0, 'dailyUsed': 0.0, 'monthlyLimit': 200000.0, 'monthlyUsed': 0.0},
      'stats': {'totalTransactions': 0, 'totalCommission': 0, 'totalSentAmount': 0, 'totalReceivedAmount': 0},
    });

    repository = TransactionRepository(
      firebaseService: mockFirebaseService,
      statsRepository: mockStatsRepository,
      cacheManager: mockCacheManager,
    );
  });

  group('TransactionRepository.createTransaction WriteBatch global stats', () {
    test('should include 5th batch operation to increment totalTransactions in stats/global doc', () async {
      // Arrange
      final transaction = TransactionModel(
        transactionId: 't1',
        storeId: 'test_store',
        walletId: 'w1',
        amount: 100.0,
        commission: 0.0,
        serviceFee: 0.0,
        transactionType: TransactionType.deposit,
        notes: 'test',
        createdBy: 'user1',
        createdById: 'user1',
        createdByName: 'User One',
        creatorRole: 'owner',
        createdAt: DateTime.now(),
        transactionDate: DateTime.now(),
      );

      // Act
      await repository.createTransaction(transaction);

      // Assert
      // Verify stats/global path set operation is called
      verify(() => mockFirestore.doc('stores/test_store/stats/global')).called(1);
      
      // Verify that the batch.set is called for the global stats document
      // with totalTransactions incremented and SetOptions(merge: true)
      verify(() => mockBatch.set<Map<String, dynamic>>(
        any(that: isA<DocumentReference<Map<String, dynamic>>>()),
        any(that: equals({'totalTransactions': FieldValue.increment(1)})),
        any(that: isA<SetOptions>()),
      )).called(1);
      
      // Verify batch commit
      verify(() => mockBatch.commit()).called(1);
    });
  });
}
