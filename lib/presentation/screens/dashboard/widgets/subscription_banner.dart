import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/subscription_provider.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final subscription = authProvider.currentStore?.subscription;
    final latestRequest = subProvider.latestRequest;

    if (subscription == null) return const SizedBox.shrink();

    // Prioritize showing latest request statuses first
    if (latestRequest != null) {
      if (latestRequest.status == 'pending') {
        return _buildBanner(
          context,
          icon: Icons.access_time_filled,
          color: Colors.orange,
          message: 'يتم الآن مراجعة طلب الاشتراك الخاص بك. لن ينقطع الخدمة خلال هذه الفترة.',
        );
      } else if (latestRequest.status == 'approved' && !subscription.isExpired) {
        // Technically if it's approved, the cloud function updates the subscription.
        // But if we want to show a short banner, we can just optionally show it.
        // It mostly matters for rejection.
      } else if (latestRequest.status == 'rejected') {
        return _buildBanner(
          context,
          icon: Icons.error,
          color: Colors.red,
          message: 'تم رفض طلب الاشتراك الأخير. يرجى مراجعة الدعم أو تقديم طلب جديد.',
        );
      }
    } else if (subscription.pendingRequestDate != null) {
      // Fallback if latestRequest isn't available yet or something
      return _buildBanner(
        context, 
        icon: Icons.access_time_filled, 
        color: Colors.orange, 
        message: 'يتم الآن مراجعة طلب الاشتراك الخاص بك. لن ينقطع الخدمة خلال هذه الفترة.',
      );
    }
    
    // Check if expired
    if (subscription.isExpired) {
       return _buildBanner(
         context, 
         icon: Icons.warning_rounded, 
         color: Colors.redAccent, 
         message: 'انتهت صلاحية اشتراكك. يرجى التجديد لتجنب إيقاف الخدمة.',
       );
    }
    
    // Check if trial with <= 3 days left
    if (authProvider.isTrial) {
      final daysLeft = authProvider.trialDaysRemaining ?? 0;
      if (daysLeft <= 3 && daysLeft > 0) {
        return _buildBanner(
         context, 
         icon: Icons.info_outline, 
         color: Colors.blueAccent, 
         message: 'باقي $daysLeft يوم على انتهاء الفترة التجريبية. قم بالترقية الآن.',
       );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(BuildContext context, {required IconData icon, required Color color, required String message}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
