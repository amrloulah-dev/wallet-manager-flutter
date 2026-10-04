import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

import 'package:get_it/get_it.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';

class MockOverlayUseCase extends Mock implements OverlayUseCase {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sl = GetIt.instance;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUp(() {
    mockSettingsProvider = MockPlatformSettingsProvider();
    when(() => mockSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());
    if (!sl.isRegistered<PlatformSettingsProvider>()) {
      sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);
    }
  });

  tearDown(() {
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
  });

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

    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);
    when(() => mockStorage.clearSession()).thenAnswer((_) async {});

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

    expect(provider.errorMessage, isNotNull);
    expect(notificationCount, greaterThan(0),
        reason: 'UI should be notified of the error');
  });

  testWidgets(
      'OverlayProvider.submitTransaction() should clearCurrentActiveSms, reset commission to 0.0, and close overlay immediately (Instant-Kill)',
      (tester) async {
    int closeOverlayCount = 0;
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay') {
        closeOverlayCount++;
        return true;
      }
      if (methodCall.method == 'shareData') {
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

    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.userId).thenReturn('user_123');
    when(() => mockStorage.storeId).thenReturn('store_123');
    when(() => mockStorage.userName).thenReturn('Test User');
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);
    when(() => mockStorage.clearCurrentActiveSms()).thenAnswer((_) async {});

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

    await provider.submitTransaction();

    expect(provider.commission, 0.0);
    verify(() => mockStorage.clearCurrentActiveSms()).called(1);
    expect(closeOverlayCount, 1);
  });

  testWidgets(
      'OverlayProvider.close() should clearCurrentActiveSms and close overlay immediately',
      (tester) async {
    int closeOverlayCount = 0;
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay') {
        closeOverlayCount++;
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

    when(() => mockStorage.clearCurrentActiveSms()).thenAnswer((_) async {});

    await provider.close();

    verify(() => mockStorage.clearCurrentActiveSms()).called(1);
    expect(closeOverlayCount, 1);
  });

  testWidgets(
      'OverlayProvider.dismissAll() should clearCurrentActiveSms and close overlay immediately',
      (tester) async {
    int closeOverlayCount = 0;
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay') {
        closeOverlayCount++;
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

    when(() => mockStorage.clearCurrentActiveSms()).thenAnswer((_) async {});

    await provider.dismissAll();

    verify(() => mockStorage.clearCurrentActiveSms()).called(1);
    expect(closeOverlayCount, 1);
  });

  testWidgets(
      'OverlayProvider.submitTransaction() should retain active SMS and keep overlay open if write fails',
      (tester) async {
    int closeOverlayCount = 0;
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay') {
        closeOverlayCount++;
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

    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.userId).thenReturn('user_123');
    when(() => mockStorage.storeId).thenReturn('store_123');
    when(() => mockStorage.userName).thenReturn('Test User');
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);
    when(() => mockStorage.clearCurrentActiveSms()).thenAnswer((_) async {});
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
        )).thenThrow(Exception('Firestore write failed'));

    await provider.submitTransaction();

    // Verify error state
    expect(provider.errorMessage, 'overlay_error_submit_failed');
    expect(provider.isLoading, false);
    // Active SMS must NOT be cleared on failure
    verifyNever(() => mockStorage.clearCurrentActiveSms());
    // Overlay must NOT be closed on failure
    expect(closeOverlayCount, 0);
  });
}
