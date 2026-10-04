import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/error_translator.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

void main() {
  group('ErrorTranslator.getLocalizedString', () {
    testWidgets('maps auth errors to a non-null localized string',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              expect(
                ErrorTranslator.getLocalizedString(
                    context, 'auth_error_account_not_found'),
                isNotEmpty,
              );
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('returns the original code when no mapping exists',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              expect(
                ErrorTranslator.getLocalizedString(context, 'unknown_code'),
                equals('unknown_code'),
              );
              return Container();
            },
          ),
        ),
      );
    });
  });
}
