import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import 'package:walletmanager/providers/auth_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late WalletUseCase walletUseCase;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    walletUseCase = WalletUseCase(authProvider: mockAuthProvider);
  });

  group('WalletUseCase.validatePermission', () {
    test(
        'throws PermissionException when ensureUserLoaded throws PermissionDeniedException',
        () async {
      when(() => mockAuthProvider.ensureUserLoaded())
          .thenThrow(PermissionDeniedException());

      expect(
        () => walletUseCase.validatePermission((p) => p.createTransaction),
        throwsA(isA<PermissionException>()),
      );
    });

    test('throws AuthException session_expired when user is null', () async {
      when(() => mockAuthProvider.ensureUserLoaded())
          .thenAnswer((_) async => null);

      expect(
        () => walletUseCase.validatePermission((p) => p.createTransaction),
        throwsA(isA<AuthException>()),
      );
    });

    test('returns user when user is owner', () async {
      final owner = UserModel(
        userId: 'owner1',
        firebaseUid: 'uid1',
        storeId: 'store1',
        role: UserRole.owner,
        fullName: 'Owner Test',
        isActive: true,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuthProvider.ensureUserLoaded())
          .thenAnswer((_) async => owner);

      final result =
          await walletUseCase.validatePermission((p) => p.createTransaction);
      expect(result, equals(owner));
    });

    test('throws PermissionException when employee lacks permission', () async {
      final employee = UserModel(
        userId: 'emp1',
        firebaseUid: 'uid2',
        storeId: 'store1',
        role: UserRole.employee,
        fullName: 'Employee Test',
        isActive: true,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        permissions: UserPermissions(createTransaction: false),
      );

      when(() => mockAuthProvider.ensureUserLoaded())
          .thenAnswer((_) async => employee);

      expect(
        () => walletUseCase.validatePermission((p) => p.createTransaction),
        throwsA(isA<PermissionException>()),
      );
    });
  });
}
