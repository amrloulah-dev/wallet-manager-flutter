import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {}
class MockIosDeviceInfo extends Mock implements IosDeviceInfo {}

void main() {
  late DeviceRepository repository;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockDeviceInfoPlugin mockDeviceInfo;
  late MockLocalStorageService mockLocalStorage;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockDeviceInfo = MockDeviceInfoPlugin();
    mockLocalStorage = MockLocalStorageService();

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test_uid');
    
    // Default: local storage is empty
    when(() => mockLocalStorage.persistentDeviceId).thenReturn(null);
    when(() => mockLocalStorage.savePersistentDeviceId(any())).thenAnswer((_) async => {});

    repository = DeviceRepository(
      firestore: mockFirestore,
      auth: mockAuth,
      deviceInfoPlugin: mockDeviceInfo,
      localStorageService: mockLocalStorage,
    );
  });

  group('DeviceRepository.getDeviceId', () {
    test('should return saved ID from LocalStorageService if it exists', () async {
      when(() => mockLocalStorage.persistentDeviceId).thenReturn('saved_uuid');

      final result = await repository.getDeviceId();

      expect(result, 'saved_uuid');
      verifyNever(() => mockDeviceInfo.androidInfo);
      verifyNever(() => mockDeviceInfo.iosInfo);
    });

    test('should generate, save and return new UUID if both local storage and platform info fail', () async {
      when(() => mockLocalStorage.persistentDeviceId).thenReturn(null);
      // Simulate platform failure or unknown
      if (Platform.isAndroid) {
        final mockAndroid = MockAndroidDeviceInfo();
        when(() => mockAndroid.id).thenReturn('unknown');
        when(() => mockDeviceInfo.androidInfo).thenAnswer((_) async => mockAndroid);
      } else if (Platform.isIOS) {
        final mockIos = MockIosDeviceInfo();
        when(() => mockIos.identifierForVendor).thenReturn(null);
        when(() => mockDeviceInfo.iosInfo).thenAnswer((_) async => mockIos);
      }

      final result = await repository.getDeviceId();

      expect(result, isNotEmpty);
      expect(result.length, 36); // UUID length
      verify(() => mockLocalStorage.savePersistentDeviceId(result)).called(1);
    });
  });

  group('DeviceRepository (Legacy)', () {
    test('registerDeviceUsage should include ownerUid in the payload', () async {
      const deviceId = 'test_device';
      const storeId = 'test_store';
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async => {});

      await repository.registerDeviceUsage(deviceId, storeId);

      verify(() => mockFirestore.collection('device_registrations')).called(1);
      verify(() => mockDocRef.set(
        captureAny(that: containsPair('ownerUid', 'test_uid')),
        any(),
      )).called(1);
    });
  });
}
