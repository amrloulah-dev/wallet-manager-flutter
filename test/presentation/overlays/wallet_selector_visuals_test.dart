import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/presentation/utils/wallet_extensions.dart';
import 'package:walletmanager/presentation/widgets/common/custom_dropdown.dart';

void main() {
  group('WalletProviderVisuals Unit Tests', () {
    test('InstaPay maps to bank icon and purple accent', () {
      final visuals = WalletProviderVisuals.fromWalletType(WalletType.instaPay);
      expect(visuals.icon, equals(Icons.account_balance_rounded));
      expect(visuals.color, equals(const Color(0xFF5C2D91)));
      expect(visuals.label, equals('إنستاباي'));
    });

    test('Vodafone Cash maps to wallet icon and red accent', () {
      final visuals =
          WalletProviderVisuals.fromWalletType(WalletType.vodafoneCash);
      expect(visuals.icon, equals(Icons.account_balance_wallet_rounded));
      expect(visuals.color, equals(Colors.red));
      expect(visuals.label, equals('فودافون كاش'));
    });

    test('Orange Cash maps to wallet icon and orange accent', () {
      final visuals =
          WalletProviderVisuals.fromWalletType(WalletType.orangeCash);
      expect(visuals.icon, equals(Icons.account_balance_wallet_rounded));
      expect(visuals.color, equals(Colors.orange));
      expect(visuals.label, equals('أورانج كاش'));
    });

    test('Etisalat Cash maps to wallet icon and green accent', () {
      final visuals =
          WalletProviderVisuals.fromWalletType(WalletType.etisalatCash);
      expect(visuals.icon, equals(Icons.account_balance_wallet_rounded));
      expect(visuals.color, equals(Colors.green));
      expect(visuals.label, equals('اتصالات كاش'));
    });

    test('WE Pay maps to wallet icon and purple accent', () {
      final visuals = WalletProviderVisuals.fromWalletType(WalletType.wePay);
      expect(visuals.icon, equals(Icons.account_balance_wallet_rounded));
      expect(visuals.color, equals(Colors.purple));
      expect(visuals.label, equals('وي باي'));
    });

    test('Other maps to outlined wallet icon and blueGrey accent', () {
      final visuals = WalletProviderVisuals.fromWalletType(WalletType.other);
      expect(visuals.icon, equals(Icons.account_balance_wallet_outlined));
      expect(visuals.color, equals(Colors.blueGrey));
      expect(visuals.label, equals('أخرى'));
    });

    test('fromRawType parses case-insensitive raw strings', () {
      final v1 = WalletProviderVisuals.fromRawType('instapay');
      expect(v1.icon, equals(Icons.account_balance_rounded));
      expect(v1.color, equals(const Color(0xFF5C2D91)));

      final v2 = WalletProviderVisuals.fromRawType('vodafone_cash');
      expect(v2.icon, equals(Icons.account_balance_wallet_rounded));
      expect(v2.color, equals(Colors.red));

      final v3 = WalletProviderVisuals.fromRawType(null);
      expect(v3.icon, equals(Icons.account_balance_wallet_outlined));
      expect(v3.color, equals(Colors.blueGrey));
    });
  });

  group('CustomDropdown Widget Tests', () {
    testWidgets('Renders selectedItemWidgetBuilder without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: CustomDropdown<String>(
                value: 'w1',
                itemsList: const ['w1', 'w2'],
                itemWidgetBuilder: (context, id) {
                  return Text('Open: $id');
                },
                selectedItemWidgetBuilder: (context, id) {
                  final visuals =
                      WalletProviderVisuals.fromWalletType(WalletType.instaPay);
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: visuals.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            Icon(visuals.icon, size: 16, color: visuals.color),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '\u200E01012345678\u200E',
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: visuals.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: visuals.color.withOpacity(0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          visuals.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: visuals.color,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('\u200E01012345678\u200E'), findsOneWidget);
      expect(find.text('إنستاباي'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    });

    testWidgets('Renders Vodafone Cash 11 digits without ellipsis or overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: CustomDropdown<String>(
                value: 'w_voda',
                itemsList: const ['w_voda'],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                itemWidgetBuilder: (context, id) => Text('Open: $id'),
                selectedItemWidgetBuilder: (context, id) {
                  final visuals = WalletProviderVisuals.fromWalletType(
                      WalletType.vodafoneCash);
                  const phoneNumber = '01006646466';
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: visuals.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            Icon(visuals.icon, size: 15, color: visuals.color),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        flex: 3,
                        child: Text(
                          '\u200E$phoneNumber\u200E',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.loose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: visuals.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: visuals.color.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            visuals.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: visuals.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('\u200E01006646466\u200E'), findsOneWidget);
      expect(find.text('فودافون كاش'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    });
  });
}
