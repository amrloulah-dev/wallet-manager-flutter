import 'package:flutter_test/flutter_test.dart';
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
  });

  group('Phase 4: Tech Debt & Hot Path Optimization', () {
    test('handleIncomingSms logic remains intact', () async {
      // This is a sanity check test for the pipeline
      final message = SmsMessage(
        address: 'VodafoneCash',
        body: 'تم استلام مبلغ 100 جنيه من رقم 01012345678',
        date: DateTime.now().millisecondsSinceEpoch,
      );

      // Mock storage methods used in pipeline
      when(() => mockStorage.getSimMappings()).thenReturn([]);
      
      // We expect the pipeline to run without crashing 
      // even if no match is found.
      await handleIncomingSms(message, mockStorage);
    });
  });
}
