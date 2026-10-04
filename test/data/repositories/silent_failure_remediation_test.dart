import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockTransaction mockTransaction;
  late MockDocumentSnapshot mockSnapshot;
  late WalletRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeDocumentReference());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    mockFirestore = MockFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockTransaction = MockTransaction();
    mockSnapshot = MockDocumentSnapshot();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);

    // Mock runTransaction
    when(() => mockFirestore.runTransaction<void>(any()))
        .thenAnswer((invocation) async {
      final transactionHandler = invocation.positionalArguments[0]
          as Future<void> Function(Transaction);
      await transactionHandler(mockTransaction);
    });

    final statsRepository = StatsRepository(firestore: mockFirestore);
    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      statsRepository: statsRepository,
    );
  });

  group('Silent Failure Remediation (TDD)', () {
    test('updateWallet should propagate ServerException on Firestore error',
        () async {
      // ARRANGE
      when(() => mockTransaction.get(any()))
          .thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockTransaction.update(any(), any()))
          .thenThrow(Exception('Firestore Error'));

      // ACT & ASSERT
      expect(() => repository.updateWallet('id', {}),
          throwsA(isA<ServerException>()));
    });
  });
}
