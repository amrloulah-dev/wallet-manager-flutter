import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

class MockOverlayUseCase extends Mock implements OverlayUseCase {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  test(
      'OverlayProvider.notifyListeners() should propagate errors even if _blockAutoFetch is true',
      () async {
    final mockUseCase = MockOverlayUseCase();
    final mockStorage = MockLocalStorageService();

    final provider = OverlayProvider(
      overlayUseCase: mockUseCase,
      localStorageService: mockStorage,
    );

    int notificationCount = 0;
    provider.addListener(() {
      notificationCount++;
    });

    // Simulate ingestNewEvent setting an error while _blockAutoFetch is active
    // We can't directly set _blockAutoFetch, so we simulate the flow in ingestNewEvent

    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);
    when(() => mockStorage.clearSession()).thenAnswer((_) async {});
    // ingestNewEvent sets _blockAutoFetch = true

    final data = {
      'amount': -100.0, // Trigger validation error (negative amount)
      'type': 'credit',
      'sender': '0123456789',
      'walletId': 'w1'
    };

    when(() => mockStorage.getCachedWalletLiteList()).thenReturn([
      {'id': 'w1', 'walletType': 'instapay'}
    ]);
    when(() => mockStorage.subIsSuspended).thenReturn(false);
    when(() => mockStorage.subSmsEnabled).thenReturn(true);

    await provider.ingestNewEvent(data);

    // After ingestNewEvent, _errorMessage should be set and UI should be notified
    expect(provider.errorMessage, isNotNull);
    expect(notificationCount, greaterThan(0),
        reason: 'UI should be notified of the error');
  });

  testWidgets(
      'OverlayProvider.submitTransaction() should reset commission to 0.0 on success',
      (tester) async {
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay' ||
          methodCall.method == 'shareData') {
        return true;
      }
      return null;
    });

    final mockUseCase = MockOverlayUseCase();
    final mockStorage = MockLocalStorageService();

    final provider = OverlayProvider(
      overlayUseCase: mockUseCase,
      localStorageService: mockStorage,
    );

    // Setup initial data so submission doesn't fail early
    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.userId).thenReturn('user_123');
    when(() => mockStorage.storeId).thenReturn('store_123');
    when(() => mockStorage.userName).thenReturn('Test User');
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);

    when(() => mockStorage.getCachedWalletLiteList()).thenReturn([
      {'id': 'w1', 'walletType': 'instapay'}
    ]);
    when(() => mockStorage.subIsSuspended).thenReturn(false);
    when(() => mockStorage.subSmsEnabled).thenReturn(true);

    await provider.ingestNewEvent({
      'amount': 100.0,
      'type': 'credit',
      'sender': '0123456789',
      'walletId': 'w1'
    });

    provider.setCommission('10.0');
    expect(provider.commission, 10.0);

    // Mock execute call
    when(() => mockUseCase.execute(
          storeId: any(named: 'storeId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
          userRole: any(named: 'userRole'),
          selectedWalletId: any(named: 'selectedWalletId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          commission: any(named: 'commission'),
          sender: any(named: 'sender'),
          availableWallets: any(named: 'availableWallets'),
        )).thenAnswer((_) async => TransactionResult(
          txId: 'tx_123',
          totalDeduction: 100.0,
          isSend: false,
        ));

    // Submit transaction
    await provider.submitTransaction();

    // Verify commission is reset to 0.0
    expect(provider.commission, 0.0);
  });
}
