import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/error_mapper.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

void main() {
  group('ErrorMapper.getLocalizedString', () {
    testWidgets('maps auth errors correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              expect(
                ErrorMapper.getLocalizedString(
                    context, 'auth_error_account_not_found'),
                isNotNull,
              );
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('returns original string if no mapping exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              expect(
                ErrorMapper.getLocalizedString(context, 'unknown_code'),
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
