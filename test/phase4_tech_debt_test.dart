import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalStorageService mockStorage;

  setUp(() async {
    mockStorage = MockLocalStorageService();
    SharedPreferences.setMockInitialValues({});

    // Mock local notifications channel
    const MethodChannel('dexterous.com/flutter_local_notifications')
        .setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'initialize') {
        return true;
      }
      return null;
    });
  });

  group('Phase 4: Tech Debt & Hot Path Optimization', () {
    test('handleIncomingSms logic remains intact', () async {
      // Mock required storage properties
      when(() => mockStorage.isSmsAutomationEnabled).thenReturn(true);
      when(() => mockStorage.subIsSuspended).thenReturn(false);
      when(() => mockStorage.subSmsEnabled).thenReturn(true);
      when(() => mockStorage.isSubLifetime).thenReturn(true);
      when(() => mockStorage.getSimMappings()).thenReturn([]);
      when(() => mockStorage.saveToVault(any())).thenAnswer((_) async {});

      // This is a sanity check test for the pipeline
      final message = SmsMessage.fromMap({
        'address': 'VodafoneCash',
        'body': 'تم استلام مبلغ 100 جنيه من رقم 01012345678',
        'date': DateTime.now().millisecondsSinceEpoch.toString(),
      }, [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE]);

      // Mock storage methods used in pipeline
      when(() => mockStorage.getSimMappings()).thenReturn([]);
      
      // We expect the pipeline to run without crashing 
      // even if no match is found.
      await handleIncomingSms(message, mockStorage);
    });
  });
}
