// [TEMP DIAGNOSTIC]
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/screens/settings/widgets/sms_parser_playground_card.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': 'Pasted SMS content from clipboard'};
      }
      return null;
    });
  });

  Widget buildTestableWidget({bool initiallyExpanded = true}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SmsParserPlaygroundCard(initiallyExpanded: initiallyExpanded),
        ),
      ),
    );
  }

  group('SmsParserPlaygroundCard Widget Tests // [TEMP DIAGNOSTIC]', () {
    testWidgets('renders header and toggles expansion on tap', (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: false));
      await tester.pumpAndSettle();

      expect(find.text('مختبر فحص الرسائل (SMS Parser Playground)'),
          findsOneWidget);
      expect(find.text('DIAGNOSTIC'), findsOneWidget);

      // Initially collapsed, so inputs are not visible
      expect(find.text('اسم المرسل (Sender)'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('مختبر فحص الرسائل (SMS Parser Playground)'));
      await tester.pumpAndSettle();

      expect(find.text('اسم المرسل (Sender)'), findsOneWidget);
      expect(find.text('اختبار الرسالة (Test Parse)'), findsOneWidget);
    });

    testWidgets('preset chips update sender input field', (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      expect(find.text('VF-Cash'), findsWidgets);
      expect(find.text('InstaPay'), findsOneWidget);
      expect(find.text('BM'), findsOneWidget);
      expect(find.text('NBE'), findsOneWidget);
      expect(find.text('CIB'), findsOneWidget);
      expect(find.text('OrangeCash'), findsOneWidget);
      expect(find.text('WE'), findsOneWidget);

      // Tap InstaPay preset
      await tester.tap(find.text('InstaPay'));
      await tester.pumpAndSettle();

      var senderField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'اسم المرسل (Sender)'),
      );
      expect(senderField.controller?.text, 'InstaPay');

      // Tap BM preset
      await tester.tap(find.text('BM'));
      await tester.pumpAndSettle();

      senderField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'اسم المرسل (Sender)'),
      );
      expect(senderField.controller?.text, 'BM');
    });

    testWidgets('successfully parses real-world Vodafone Cash debit sample',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      const debitSms =
          'تم تحويل 165 جنيه لرقم 01025948553 مصاريف الخدمة 0 جنيه رصيد حسابك فى فودافون كاش الحالي 57260.20. تاريخ العملية 00:37 26-10-05 : رقم العملية 024383991770 : حول فلوس لأي محفظة وزود فرصك تكسب جنيه دهب! وكمان هيجيلك لحد 100ج كاش باك. http://vf.eg/vfcash?id=money_transfer';

      // Enter SMS into body input
      final bodyFinder =
          find.widgetWithText(TextField, 'نص الرسالة (SMS Body)');
      await tester.enterText(bodyFinder, debitSms);
      await tester.pumpAndSettle();

      // Tap Test Parse
      await tester.tap(find.text('اختبار الرسالة (Test Parse)'));
      await tester.pumpAndSettle();

      // Verify success card elements
      expect(
          find.text('تم التعرف بنجاح (Parsed Successfully)'), findsOneWidget);
      expect(find.text('سحب (Debit)'), findsOneWidget);
      expect(find.text('EGP 165.0'), findsOneWidget);
      expect(find.text('\u200E01025948553\u200E'), findsOneWidget);
      expect(find.text('Vodafone Cash'), findsOneWidget);
    });

    testWidgets(
        'successfully parses real-world Vodafone Cash credit sample (ignoring merchant number)',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      const creditSms =
          'تم استلام مبلغ 40400 جنيه من رقم 01033602179 المسجل بإسم Ahmed M Hassan على رقم محفظتك 01003373973. رصيدك الحالي: 65287.29 جنيه تاريخ العملية: 22:58 26-10-04 رقم العملية: 024380965565 تابع كل مصروفاتك من تاريخ المعاملات على أبلكيشن أنا فودافون http://vf.eg/vfcash';

      final bodyFinder =
          find.widgetWithText(TextField, 'نص الرسالة (SMS Body)');
      await tester.enterText(bodyFinder, creditSms);
      await tester.pumpAndSettle();

      await tester.tap(find.text('اختبار الرسالة (Test Parse)'));
      await tester.pumpAndSettle();

      expect(
          find.text('تم التعرف بنجاح (Parsed Successfully)'), findsOneWidget);
      expect(find.text('إيداع (Credit)'), findsOneWidget);
      expect(find.text('EGP 40400.0'), findsOneWidget);
      expect(find.text('\u200E01033602179\u200E'), findsOneWidget);
      expect(find.text('\u200E01003373973\u200E'), findsNothing);
      expect(find.text('Vodafone Cash'), findsOneWidget);
    });

    testWidgets('displays failure card when parsing invalid message',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      final bodyFinder =
          find.widgetWithText(TextField, 'نص الرسالة (SMS Body)');
      await tester.enterText(
          bodyFinder, 'رسالة عشوائية غير متعلقة بالمعاملات المالية');
      await tester.pumpAndSettle();

      await tester.tap(find.text('اختبار الرسالة (Test Parse)'));
      await tester.pumpAndSettle();

      expect(find.text('فشل التحليل (Parsing Failed)'), findsOneWidget);
      expect(find.text('سبب الرفض:'), findsOneWidget);
      expect(find.text('خطوة التوقف:'), findsOneWidget);
    });

    testWidgets(
        'paste button populates body input and clear button resets state',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      // Tap paste
      await tester.tap(find.text('لصق من الحافظة (Paste)'));
      await tester.pumpAndSettle();

      expect(find.text('Pasted SMS content from clipboard'), findsOneWidget);

      // Tap clear
      await tester.tap(find.text('مسح النص'));
      await tester.pumpAndSettle();

      expect(find.text('Pasted SMS content from clipboard'), findsNothing);
    });

    testWidgets(
        'successfully parses IPN credit sample with masked account reference in playground',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      // Tap InstaPay preset
      await tester.tap(find.text('InstaPay'));
      await tester.pumpAndSettle();

      const ipnCreditSms =
          'تم اضافة مبلغ 6400EGP        الى حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';

      final bodyFinder =
          find.widgetWithText(TextField, 'نص الرسالة (SMS Body)');
      await tester.enterText(bodyFinder, ipnCreditSms);
      await tester.pumpAndSettle();

      await tester.tap(find.text('اختبار الرسالة (Test Parse)'));
      await tester.pumpAndSettle();

      expect(
          find.text('تم التعرف بنجاح (Parsed Successfully)'), findsOneWidget);
      expect(find.text('إيداع (Credit)'), findsOneWidget);
      expect(find.text('EGP 6400.0'), findsOneWidget);
      expect(find.text('\u200Exxx0006\u200E'), findsOneWidget);
      expect(find.text('IPN/Bank'), findsOneWidget);
    });

    testWidgets(
        'successfully parses IPN debit sample with masked account reference in playground',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(initiallyExpanded: true));
      await tester.pumpAndSettle();

      // Tap BM preset
      await tester.tap(find.text('BM'));
      await tester.pumpAndSettle();

      const ipnDebitSms =
          'تم تحويل مبلغ 900EGP        من حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';

      final bodyFinder =
          find.widgetWithText(TextField, 'نص الرسالة (SMS Body)');
      await tester.enterText(bodyFinder, ipnDebitSms);
      await tester.pumpAndSettle();

      await tester.tap(find.text('اختبار الرسالة (Test Parse)'));
      await tester.pumpAndSettle();

      expect(
          find.text('تم التعرف بنجاح (Parsed Successfully)'), findsOneWidget);
      expect(find.text('سحب (Debit)'), findsOneWidget);
      expect(find.text('EGP 900.0'), findsOneWidget);
      expect(find.text('\u200Exxx0006\u200E'), findsOneWidget);
      expect(find.text('IPN/Bank'), findsOneWidget);
    });
  });
}
