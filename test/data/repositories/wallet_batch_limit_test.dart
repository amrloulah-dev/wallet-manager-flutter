import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockWriteBatch extends Mock implements WriteBatch {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockWriteBatch mockBatch;
  late MockFirebaseService mockFirebaseService;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late WalletRepository repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockBatch = MockWriteBatch();
    mockFirebaseService = MockFirebaseService();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    final statsRepository = StatsRepository(firestore: mockFirestore);
    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      statsRepository: statsRepository,
    );
  });

  group('Batch Limit (TDD)', () {
    test(
        'resetLimitsForWallets should use multiple batches if count exceeds 450',
        () async {
      // ARRANGE: Create 500 wallets that need reset
      final wallets = <WalletModel>[];
      final oldDate = DateTime.now().subtract(const Duration(days: 2));
      for (var i = 0; i < 500; i++) {
        final wallet = WalletModel.fromWalletStatus(
          walletId: 'wallet_$i',
          storeId: 'test_store',
          phoneNumber: '010$i',
          walletType: 'vodafoneCash',
          walletStatus: 'active',
          balance: 100.0,
          createdBy: 'test_user',
        ).copyWith(lastDailyReset: oldDate, lastMonthlyReset: oldDate);
        wallets.add(wallet);
      }

      // ACT
      await repository.resetLimitsForWallets(wallets);

      // ASSERT
      // Currently it should call batch() only ONCE
      // But with chunking (size 450), it should call it TWICE
      verify(() => mockFirestore.batch()).called(2);
      verify(() => mockBatch.commit()).called(2);
    });
  });
}
