import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/employee/user_permissions_widget.dart';
import 'package:walletmanager/providers/employee_provider.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final UserModel employee;

  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  late UserModel _employee;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  void _showEditPermissionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPermissionsSheet(
        employee: _employee,
        onSave: (newPermissions) async {
          final provider = context.read<EmployeeProvider>();
          final success = await provider.updateEmployeePermissions(
            _employee.userId,
            newPermissions,
          );
          if (success) {
            setState(() {
              _employee = _employee.copyWith(permissions: newPermissions);
            });
            if (mounted) {
              ToastUtils.showSuccess('تم تحديث الصلاحيات بنجاح');
              Navigator.pop(context);
            }
          } else {
            if (mounted) {
              ToastUtils.showError(provider.errorMessage ?? 'حدث خطأ ما');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الموظف'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildInfoCard(),
            const SizedBox(height: 24),
            CustomButton(
              text: 'تعديل الصلاحيات',
              onPressed: _showEditPermissionsSheet,
              icon: const Icon(Icons.security),
              backgroundColor: AppColors.primary,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary.withAlpha(50),
          child: Text(
            _employee.fullName[0].toUpperCase(),
            style: AppTextStyles.h1.copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(_employee.fullName, style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _employee.isActive
                ? AppColors.success.withAlpha(50)
                : AppColors.error.withAlpha(50),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _employee.isActive ? 'نشط' : 'معطل',
            style: AppTextStyles.labelMedium.copyWith(
              color: _employee.isActive ? AppColors.success : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.phone, 'رقم الهاتف', _employee.phone ?? '-'),
          const Divider(height: 32),
          _buildInfoRow(Icons.pin, 'PIN', '****'),
          const Divider(height: 32),
          _buildInfoRow(
            Icons.calendar_today,
            'تاريخ الإضافة',
            _employee.createdAt.toDate().toString().split(' ')[0],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary(context), size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context))),
        const Spacer(),
        Text(value, style: AppTextStyles.h3),
      ],
    );
  }
}

class _EditPermissionsSheet extends StatefulWidget {
  final UserModel employee;
  final Function(UserPermissions) onSave;

  const _EditPermissionsSheet({
    required this.employee,
    required this.onSave,
  });

  @override
  State<_EditPermissionsSheet> createState() => _EditPermissionsSheetState();
}

class _EditPermissionsSheetState extends State<_EditPermissionsSheet> {
  late UserPermissions _currentPermissions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPermissions =
        widget.employee.permissions ?? UserPermissions.defaultPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text('تعديل الصلاحيات', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: UserPermissionsWidget(
                initialPermissions: _currentPermissions,
                onPermissionsChanged: (perms) {
                  setState(() => _currentPermissions = perms);
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border:
                  Border(top: BorderSide(color: AppColors.divider(context))),
            ),
            child: Consumer<EmployeeProvider>(
              builder: (context, provider, _) {
                // Local loading state is handled by checking provider.isLoading
                // but simpler to use local state implicitly via callback logic
                // However, we want to show loading on the button.
                // The parent callback calls provider, which sets isLoading.
                // So we can use provider.isLoading if we want, OR just pass a loading state.
                // A simplier approach:
                return CustomButton(
                  text: 'حفظ التغييرات',
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    await widget.onSave(_currentPermissions);
                    if (mounted) setState(() => _isLoading = false);
                  },
                  isLoading: _isLoading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
