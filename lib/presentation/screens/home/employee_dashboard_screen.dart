import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:walletmanager/core/utils/permission_helper.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../widgets/dashboard/quick_action_card.dart';
import '../../widgets/dashboard/section_header.dart';
import '../../widgets/transaction/transaction_card.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<TransactionProvider>().fetchInitialTransactions();
  }

  Future<void> _showLogoutDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool? confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmText: 'خروج',
      type: DialogType.danger,
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, RouteConstants.storeRegistration);
      }
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير 🌅';
    if (hour < 17) return 'مساء الخير ☀️';
    return 'مساء الخير 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الموظف'),
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(),
                  _buildRecentTransactions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final store = authProvider.currentStore;
    final avatarLetter = user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'E';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 32, child: Text(avatarLetter, style: AppTextStyles.h1)),
                  const SizedBox(height: 16),
                  Text(user?.fullName ?? 'موظف', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(store?.storeName ?? 'متجر', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  if (PermissionHelper.canAccessScreen(context, 'DashboardScreen'))
                    _DrawerMenuTile(title: 'الرئيسية', icon: Icons.dashboard_outlined, isSelected: true, onTap: () => Navigator.pop(context)),
                  if (PermissionHelper.canAccessScreen(context, 'TodayTransactionsScreen'))
                    _DrawerMenuTile(title: 'المعاملات', icon: Icons.receipt_long_outlined, onTap: () => Navigator.pushNamed(context, RouteConstants.todayTransactions)),
                  if (PermissionHelper.canAccessScreen(context, 'DebtsListScreen'))
                    _DrawerMenuTile(title: 'الديون', icon: Icons.credit_card_outlined, onTap: () => Navigator.pushNamed(context, RouteConstants.debtsList)),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _DrawerMenuTile(title: 'تسجيل الخروج', icon: Icons.logout, iconColor: AppColors.error, textColor: AppColors.error, onTap: _showLogoutDialog),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withAlpha((0.8 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreetingMessage(), style: AppTextStyles.h3.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(authProvider.currentUser?.fullName ?? 'موظف', style: AppTextStyles.h1.copyWith(color: Colors.white)),
              ],
            ),
          ),
        );
      },

    );
  }

  Widget _buildQuickActions() {
    final List<Widget> actions = [];

    if (PermissionHelper.canCreateTransactions(context)) {
      actions.add(QuickActionCard(title: 'معاملة جديدة', icon: Icons.add_circle_outline, color: AppColors.primary, onTap: () => Navigator.pushNamed(context, RouteConstants.createTransaction)));
    }
    if (PermissionHelper.canCreateDebt(context)) {
      actions.add(QuickActionCard(title: 'دين جديد', icon: Icons.post_add_outlined, color: AppColors.error, onTap: () => Navigator.pushNamed(context, RouteConstants.addDebt)));
    }
    if (PermissionHelper.canAccessScreen(context, 'DebtsListScreen')) {
       actions.add(QuickActionCard(title: 'عرض الديون', icon: Icons.credit_card, color: Colors.red.shade700, onTap: () => Navigator.pushNamed(context, RouteConstants.debtsList)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الإجراءات المتاحة'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.95),
          itemCount: actions.length,
          itemBuilder: (context, index) => actions[index],
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            SectionHeader(
              title: 'آخر معاملاتك',
              actionText: 'عرض الكل',
              onActionTap: () => Navigator.pushNamed(context, RouteConstants.todayTransactions),
            ),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const SkeletonList(itemCount: 2, itemHeight: 80)
            else if (provider.hasError)
              const Text('حدث خطأ في تحميل المعاملات')
            else if (provider.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'لا توجد معاملات اليوم.',
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else
              Builder(builder: (context) {
                final currentUser = context.read<AuthProvider>().currentUser;
                final employeeTransactions = provider.transactions
                    .where((t) => t.createdBy == currentUser?.userId)
                    .toList();

                if (employeeTransactions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'لم تقم بأي معاملات اليوم.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employeeTransactions.take(5).length,
                  itemBuilder: (context, index) {
                    final transaction = employeeTransactions.elementAt(index);
                    return TransactionCard(
                      transaction: transaction,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteConstants.transactionDetails,
                        arguments: transaction.transactionId,
                      ),
                    );
                  },
                );
              }),
          ],
        );
      },
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerMenuTile({required this.title, required this.icon, required this.onTap, this.isSelected = false, this.iconColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? (isSelected ? AppColors.primary : AppColors.textSecondary(context));
    final effectiveTextColor = textColor ?? (isSelected ? AppColors.primary : AppColors.textPrimary(context));

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: effectiveIconColor),
      title: Text(title, style: AppTextStyles.labelLarge.copyWith(color: effectiveTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withAlpha((0.1 * 255).round()),
    );
  }
}