import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/presentation/widgets/common/empty_state_widget.dart';
import 'package:walletmanager/presentation/widgets/common/error_widget.dart';
import 'package:walletmanager/presentation/widgets/common/loading_indicator.dart';
import 'package:walletmanager/presentation/widgets/employee/employee_card.dart';
import 'package:walletmanager/providers/employee_provider.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  @override
  void initState() {
    super.initState();
    // Data is now loaded reactively by the provider's stream.
  }

  void _navigateToAddEmployee() {
    Navigator.pushNamed(context, RouteConstants.addEmployee);
  }

  Future<void> _showDeactivateDialog(UserModel employee) async {
    final provider = context.read<EmployeeProvider>();
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: 'تعطيل حساب الموظف',
      message: 'هل أنت متأكد أنك تريد تعطيل حساب ${employee.fullName}؟\n\nلن يتمكن من تسجيل الدخول بعد الآن.',
      confirmText: 'تعطيل',
      type: DialogType.danger,
    );

    if (confirmed == true) {
      final success = await provider.deactivateEmployee(employee.userId);
      if (mounted) {
        if (success) {
          ToastUtils.showSuccess('تم تعطيل حساب الموظف');
        } else {
          ToastUtils.showError(provider.errorMessage ?? 'فشل تعطيل الحساب');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموظفين'),
        centerTitle: true,
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.employees.isEmpty) {
            return const LoadingIndicator(message: 'جاري تحميل الموظفين...');
          }

          if (provider.hasError && provider.employees.isEmpty) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? 'حدث خطأ أثناء تحميل الموظفين',
              onRetry: () => provider.refresh(),
            );
          }

          if (provider.employees.isEmpty) {
            return EmptyStateWidget(
              message: 'لا يوجد موظفين',
              description: 'ابدأ بإضافة موظف جديد لإدارة صلاحياته.',
              icon: Icons.people_outline,
              actionText: 'إضافة موظف',
              onAction: _navigateToAddEmployee,
            );
          }

          final activeEmployees = provider.activeEmployees;
          final inactiveEmployees = provider.inactiveEmployees;

          return ListView(
            padding: const EdgeInsets.only(bottom: 80), // For FAB
            children: [
              if (activeEmployees.isNotEmpty)
                _buildEmployeeSection('الموظفين النشطين', activeEmployees),
              if (inactiveEmployees.isNotEmpty)
                _buildEmployeeSection('الموظفين المعطلين', inactiveEmployees),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddEmployee,
        icon: const Icon(Icons.add),
        label: const Text('إضافة موظف'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmployeeSection(String title, List<UserModel> employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return EmployeeCard(
              employee: employee,
              onDelete: employee.isActive ? () => _showDeactivateDialog(employee) : null,
            );
          },
        ),
      ],
    );
  }
}
