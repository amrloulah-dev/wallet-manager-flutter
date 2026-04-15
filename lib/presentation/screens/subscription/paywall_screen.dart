import 'package:flutter/material.dart';
import '../../../providers/system_config_provider.dart';
import 'package:provider/provider.dart';
import 'payment_modal_screen.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final systemConfigs = context.watch<SystemConfigProvider>().configs;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ترقية الحساب'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              Text(
                'فتح إمكانيات متجرك',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'توقف عن إدخال البيانات يدويا. قم بأتمتة التدفق النقدي الخاص بك بأمان مع الميزات المتقدمة.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Pro Yearly Plan
              _buildPlanCard(
                context,
                title: 'باقة برو السنوية',
                price: '999 جنيه / سنة',
                features: [
                  'مزامنة المعاملات تلقائيا',
                  'إدارة حتى 50 محفظة',
                  'إنشاء حسابات للموظفين',
                  'دعم فني متخصص',
                ],
                isPopular: true,
                onTap: () => PaymentModalScreen.show(context, 'pro_yearly'),
              ),
              const SizedBox(height: 24),
              
              // Lifetime VIP Plan
              if (systemConfigs.lifetimePlanEnabled)
                _buildPlanCard(
                  context,
                  title: 'باقة مدى الحياة',
                  price: '2999 جنيه فقط مره واحده',
                  scarcityText: systemConfigs.remainingLifetimeSeats > 0
                      ? 'متبقي ${systemConfigs.remainingLifetimeSeats} مقاعد فقط!'
                      : 'نفدت الكمية',
                  isDisabled: systemConfigs.remainingLifetimeSeats <= 0,
                  features: [
                    'عدد لا نهائي من المحافظ',
                    'عدد لا نهائي من الموظفين',
                    'إشعارات SMS للعملاء',
                    'أولوية الدعم الفني VIP',
                  ],
                  isPopular: false,
                  color: Colors.purple.shade700,
                  onTap: systemConfigs.remainingLifetimeSeats > 0 
                      ? () => PaymentModalScreen.show(context, 'lifetime')
                      : null,
                ),
              if (systemConfigs.lifetimePlanEnabled)
                const SizedBox(height: 32),
              
              const Text(
                'بمتابعة العملية أنت توافق على شروط الخدمة وسياسة الخصوصية الخاصة بنا.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    VoidCallback? onTap,
    bool isPopular = false,
    String? scarcityText,
    bool isDisabled = false,
    Color? color,
  }) {
    final themeColor = color ?? Theme.of(context).primaryColor;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? Colors.amber : (isDisabled ? Colors.grey : themeColor.withValues(alpha: 0.3)),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDisabled ? Colors.transparent : themeColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            isDisabled ? Colors.grey.withValues(alpha: 0.05) : themeColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'الأكثر طلباً',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (scarcityText != null)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.red.shade100 : Colors.orange.shade100,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    scarcityText,
                    style: TextStyle(
                      color: isDisabled ? Colors.red.shade900 : Colors.deepOrange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? Colors.grey : themeColor,
                      decoration: isDisabled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: isDisabled ? Colors.grey : Colors.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(f, style: TextStyle(fontSize: 16, color: isDisabled ? Colors.grey : null))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDisabled ? Colors.grey : themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isDisabled ? 'غير متاح' : 'اشترك الآن', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
