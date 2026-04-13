import 'package:flutter/material.dart';
import '../../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class AdminBlockScreen extends StatelessWidget {
  const AdminBlockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.block,
                  size: 100,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 32),
                Text(
                  'تم إيقاف حسابك',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'لقد تم تعليق حسابك من قبل الإدارة. يرجى التواصل مع فريق الدعم الفني لحل هذه المشكلة واستعادة وصولك إلى النظام.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () {
                    // Could launch whatsapp or call
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جاري الاتصال بالدعم الفني...')),
                    );
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text('تواصل مع الدعم الفني'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Provider.of<AuthProvider>(context, listen: false).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
