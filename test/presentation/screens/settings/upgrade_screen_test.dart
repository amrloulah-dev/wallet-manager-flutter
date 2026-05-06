import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/settings/upgrade_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class DummyAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;

  @override
  String get licenseKey => 'N/A';

  @override
  DateTime get licenseExpiryDate => DateTime.now().add(const Duration(days: 30));

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummySubscriptionProvider extends ChangeNotifier implements SubscriptionProvider {
  @override
  int? get daysRemaining => 30;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('UpgradeScreen should be a StatefulWidget to properly manage controller lifecycle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => DummyAuthProvider()),
          ChangeNotifierProvider<SubscriptionProvider>(create: (_) => DummySubscriptionProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: UpgradeScreen(isTrial: true),
        ),
      ),
    );

    final upgradeScreen = tester.widget(find.byType(UpgradeScreen));
    expect(upgradeScreen, isA<StatefulWidget>());
  });
}
