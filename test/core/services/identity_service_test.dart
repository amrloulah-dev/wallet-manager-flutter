import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/services/identity_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
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
    when(() => mockUserCredential.user).thenReturn(mockUser);
    
    IdentityService.authOverride = mockAuth;
  });

  group('IdentityService', () {
    test('provisionIdentity creates user', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.provisionIdentity(
        phone: '123456789',
        storeId: 'store123',
        pin: 'password123',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).called(1);
    });

    test('provisionIdentity returns existing UID on duplicate email', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.provisionIdentity(
        phone: '123456789',
        storeId: 'store123',
        pin: 'password123',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).called(1);
    });

    test('updateCredential changes password', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.updatePassword('newpassword123'))
          .thenAnswer((_) async {});

      final success = await IdentityService.updateCredential(
        phone: '123456789',
        storeId: 'store123',
        newPin: 'newpassword123',
      );

      expect(success, isTrue);
      verify(() => mockUser.updatePassword('newpassword123')).called(1);
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

    test('authenticateEmployee returns UID on success', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);

      final uid = await IdentityService.authenticateEmployee(
        phone: '123456789',
        storeId: 'store123',
        pin: 'password123',
      );

      expect(uid, 'test-uid');
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'emp_123456789_store123@store.com',
            password: 'password123',
          )).called(1);
    });
  });
}
