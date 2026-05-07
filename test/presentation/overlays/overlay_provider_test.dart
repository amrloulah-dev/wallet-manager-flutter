import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOverlayUseCase extends Mock implements OverlayUseCase {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  test('OverlayProvider.notifyListeners() should propagate errors even if _blockAutoFetch is true', () async {
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
    // ingestNewEvent sets _blockAutoFetch = true
    
    final data = {
      'amount': 100000, // Trigger limit error
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
    expect(notificationCount, greaterThan(0), reason: 'UI should be notified of the error');
  });
}
