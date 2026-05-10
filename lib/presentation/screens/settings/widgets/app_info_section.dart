import 'package:flutter/material.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/arb/app_localizations.dart';
import 'section_title.dart';

class AppInfoSection extends StatelessWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: AppLocalizations.of(context)!.license),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.card_membership_outlined,
                    color: AppColors.primary),
                title: Text(AppLocalizations.of(context)!.mySubscription,
                    style: AppTextStyles.bodyLarge),
                trailing: Icon(
                  IconData(Icons.arrow_forward_ios.codePoint,
                      fontFamily: Icons.arrow_forward_ios.fontFamily,
                      matchTextDirection: true),
                  size: 16),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteConstants.subscriptionDetails,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
