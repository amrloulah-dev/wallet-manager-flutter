import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'paywall_screen.dart';
import '../../../core/theme/app_colors.dart';

class SubscriptionDetailsScreen extends StatelessWidget {
  const SubscriptionDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final subscription = authProvider.currentStore?.subscription;
    final stats = authProvider.currentStore?.stats;
    
    if (subscription == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPro = subscription.planId == 'pro_yearly';
    final isLifetime = subscription.planId == 'lifetime';
    final isTrial = subscription.planId == 'trial';
    
    String planName = 'مجاني';
    if (isPro) planName = 'برو (سنوي)';
    if (isLifetime) planName = 'مدى الحياة VIP';
    if (isTrial) planName = 'تجريبي';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الاشتراك'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(context, planName, subscription, isLifetime),
              const SizedBox(height: 24),
              const Text(
                'الاستهلاك الحالي',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildLimitItem(
                context,
                title: 'المحافظ النشطة',
                current: stats?.activeWallets ?? 0,
                max: subscription.maxWallets,
                icon: Icons.account_balance_wallet,
              ),
              const SizedBox(height: 12),
              _buildLimitItem(
                context,
                title: 'حسابات الموظفين',
                current: 1, // Example calculation: replace with actual employee count 
                max: subscription.maxEmployees,
                icon: Icons.people,
              ),
              const SizedBox(height: 32),
              if (!isLifetime) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      );
                    },
                    icon: const Icon(Icons.upgrade),
                    label: const Text('ترقية الاشتراك'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String planName, dynamic subscription, bool isLifetime) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الباقة الحالية',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subscription.status == 'active' ? 'نشط' : 'معلق',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            planName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isLifetime && subscription.endDate != null) ...[
             const Divider(),
             const SizedBox(height: 8),
             Row(
               children: [
                 const Icon(Icons.event, size: 20, color: Colors.grey),
                 const SizedBox(width: 8),
                 Text(
                   'تاريخ الانتهاء: ${subscription.endDate!.year}-${subscription.endDate!.month.toString().padLeft(2, '0')}-${subscription.endDate!.day.toString().padLeft(2, '0')}',
                   style: const TextStyle(fontSize: 16),
                 ),
               ],
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitItem(BuildContext context, {required String title, required int current, required int max, required IconData icon}) {
    final double percent = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    final isMax = max == 999;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                isMax ? '$current / ∞' : '$current / $max',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isMax)
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? Colors.red : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
        ],
      ),
    );
  }
}
