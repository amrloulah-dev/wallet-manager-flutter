import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmployeeRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  final defaultPermissions = UserPermissions(
    createTransaction: true,
    editTransaction: true,
    viewAllTransactions: true,
    viewDebts: true,
    createDebt: true,
    collectDebt: true,
    deleteDebt: true,
    viewWallets: true,
    viewWalletBalance: true,
    createWallet: true,
    addBalance: true,
    editWallet: true,
    viewDashboardStats: true,
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = EmployeeRepository(firestore: fakeFirestore);
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();
    mockAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    IdentityService.authOverride = mockAuth;

    final sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(
        mockPlatformSettingsProvider);

    const settings = PlatformSettingsModel.defaults();
    when(() => mockPlatformSettingsProvider.settings).thenReturn(settings);
  });

  tearDown(() {
    IdentityService.authOverride = null;
  });

  group('Identity-First Employee Creation', () {
    test(
        'addEmployee provisions identity first and uses auth UID as doc ID, firebaseUid, and pin_lock userId',
        () async {
      const storeId = 'store_id_1';
      const authUid = 'auth_uid_12345';
      const phone = '01000000000';
      const pin = '1234';

      // Set up store doc
      await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .set({
        'storeId': storeId,
        'subscription': {'planId': 'free'},
      });

      // Mock Auth creation
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn(authUid);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'fake_token');

      final employee = await repository.addEmployee(
        storeId: storeId,
        fullName: 'John Doe',
        phone: phone,
        pin: pin,
        permissions: defaultPermissions,
      );

      // Verify employee model
      expect(employee.userId, equals(authUid));
      expect(employee.firebaseUid, equals(authUid));

      // Verify Firestore document exists at _usersCollection.doc(authUid)
      final userDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(authUid)
          .get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['firebaseUid'], equals(authUid));

      // Verify pin_lock uses authUid as userId
      final pinLocksSnap = await fakeFirestore
          .collection(FirebaseConstants.pinLocksSubcollection(storeId))
          .get();
      expect(pinLocksSnap.docs.isNotEmpty, isTrue);
      expect(pinLocksSnap.docs.first.data()['userId'], equals(authUid));
    });

    test('addEmployee fails when identity provisioning fails', () async {
      const storeId = 'store_id_1';
      const phone = '01000000000';
      const pin = '1234';

      await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .set({
        'storeId': storeId,
        'subscription': {'planId': 'free'},
      });

      when(() => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      expect(
        () async => await repository.addEmployee(
          storeId: storeId,
          fullName: 'Jane Doe',
          phone: phone,
          pin: pin,
          permissions: defaultPermissions,
        ),
        throwsA(isA<ServerException>()),
      );

      // Verify no user doc was created
      final usersSnap = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .get();
      expect(usersSnap.docs.isEmpty, isTrue);
    });
  });
}
