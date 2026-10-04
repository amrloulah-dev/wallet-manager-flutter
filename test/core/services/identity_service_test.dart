import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/services/analytics_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUser.email).thenReturn('emp_123456789_store123@store.com');
    when(() => mockUser.getIdToken()).thenAnswer((_) async => 'mock-token');
    when(() => mockUserCredential.user).thenReturn(mockUser);

    IdentityService.authOverride = mockAuth;
  });

  group('IdentityService', () {
    test('provisionIdentity creates user with raw 6-digit PIN', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.provisionIdentity(
        phone: '123456789',
        storeId: 'store123',
        pin: '123456',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).called(1);
    });

    test(
        'provisionIdentity returns existing UID on duplicate email with raw PIN',
        () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.provisionIdentity(
        phone: '123456789',
        storeId: 'store123',
        pin: '123456',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).called(1);
    });

    test('updateCredential changes password with raw PIN', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.updatePassword('654321')).thenAnswer((_) async {});

      final success = await IdentityService.updateCredential(
        phone: '123456789',
        storeId: 'store123',
        newPin: '654321',
      );

      expect(success, isTrue);
      verify(() => mockUser.updatePassword('654321')).called(1);
    });

    test('deleteIdentity removes user', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.delete()).thenAnswer((_) async {});

      final success = await IdentityService.deleteIdentity(
        phone: '123456789',
        storeId: 'store123',
      );

      expect(success, isTrue);
      verify(() => mockUser.delete()).called(1);
    });

    test('authenticateEmployee authenticates using raw 6-digit PIN directly',
        () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.authenticateEmployee(
        phone: '123456789',
        storeId: 'store123',
        pin: '123456',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).called(1);
    });

    test(
        'authenticateEmployee throws AuthException on invalid credentials without fallback',
        () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await expectLater(
        IdentityService.authenticateEmployee(
          phone: '123456789',
          storeId: 'store123',
          pin: '123456',
        ),
        throwsA(isA<AuthException>()),
      );

      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: '123456',
          )).called(1);
    });
  });
}
