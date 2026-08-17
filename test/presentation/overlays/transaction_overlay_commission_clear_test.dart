import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/overlays/transaction_overlay_screen.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockOverlayUseCase extends Mock implements OverlayUseCase {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  const channel = MethodChannel('x-slayer/overlay_channel');
  final sl = GetIt.instance;

  late MockOverlayUseCase mockUseCase;
  late MockLocalStorageService mockStorage;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockUseCase = MockOverlayUseCase();
    mockStorage = MockLocalStorageService();
    mockSettingsProvider = MockPlatformSettingsProvider();

    sl.registerSingleton<OverlayUseCase>(mockUseCase);
    sl.registerSingleton<LocalStorageService>(mockStorage);
    sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);

    // Mock platform channel responses
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay' ||
          methodCall.method == 'shareData') {
        return true;
      }
      return null;
    });
  });

  tearDownAll(() {
    sl.reset();
  });

  testWidgets(
      'TransactionOverlayScreen clears commission text field on successful submit',
      (WidgetTester tester) async {
    // Setup Mock behaviours
    when(() => mockStorage.userId).thenReturn('user_123');
    when(() => mockStorage.storeId).thenReturn('store_123');
    when(() => mockStorage.userName).thenReturn('Test User');
    when(() => mockStorage.userRole).thenReturn(UserRole.owner);
    when(() => mockStorage.languageCode).thenReturn('en');
    when(() => mockStorage.initialize()).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.readFromVault()).thenAnswer((_) async => null);
    when(() => mockStorage.clearVault()).thenAnswer((_) async {});
    when(() => mockStorage.subIsSuspended).thenReturn(false);
    when(() => mockStorage.subSmsEnabled).thenReturn(true);
    when(() => mockStorage.getCachedWalletLiteList()).thenReturn([
      {
        'id': 'w1',
        'name': 'InstaPay Wallet',
        'walletType': 'instapay',
        'isFrozen': false
      }
    ]);

    when(() => mockSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());

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

    // Build our widget
    await tester.pumpWidget(const TransactionOverlayScreen());
    await tester.pumpAndSettle();

    final provider = Provider.of<OverlayProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false);

    await provider.ingestNewEvent({
      'amount': 100.0,
      'type': 'credit',
      'sender': '0123456789',
      'walletId': 'w1'
    });
    await tester.pumpAndSettle();

    // Find the text field (Commission)
    final txtFieldFinder = find.byType(TextField);
    expect(txtFieldFinder, findsOneWidget);

    // Enter a commission value (e.g. 15.5)
    await tester.enterText(txtFieldFinder, '15.5');
    await tester.pumpAndSettle();

    // Verify provider has received it
    expect(provider.commission, 15.5);

    // Verify dropdown is selected
    expect(provider.selectedWalletId, 'w1');

    // Tap the confirm payment button
    final btnFinder = find.byType(ElevatedButton);
    expect(btnFinder, findsOneWidget);
    await tester.tap(btnFinder);

    // Pump to let async submission execute
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify commission on provider has been reset to 0
    expect(provider.commission, 0.0);

    // Verify TextField text has been cleared
    final textWidget = tester.widget<TextField>(txtFieldFinder);
    expect(textWidget.controller?.text, '');
  });
}
