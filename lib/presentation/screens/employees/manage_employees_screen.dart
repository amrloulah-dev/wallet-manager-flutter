import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
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
import 'package:walletmanager/presentation/screens/employees/employee_details_screen.dart'; // Added import
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
      title: AppLocalizations.of(context)!.deactivateEmployeeAccount,
      message: AppLocalizations.of(context)!
          .deactivateEmployeeConfirmation(employee.fullName),
      confirmText: AppLocalizations.of(context)!.deactivate,
      type: DialogType.danger,
    );

    if (confirmed == true) {
      final success = await provider.deactivateEmployee(employee.userId);
      if (mounted) {
        if (success) {
          ToastUtils.showSuccess(
              AppLocalizations.of(context)!.employeeDeactivated);
        } else {
          ToastUtils.showError(provider.errorMessage ??
              AppLocalizations.of(context)!.deactivationFailed);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.manageEmployeesTitle),
        centerTitle: true,
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.employees.isEmpty) {
            return LoadingIndicator(
                message: AppLocalizations.of(context)!.loadingEmployees);
          }

          if (provider.hasError && provider.employees.isEmpty) {
            return CustomErrorWidget(
              message: provider.errorMessage ??
                  AppLocalizations.of(context)!.errorLoadingEmployees,
              onRetry: () => provider.refresh(),
            );
          }

          if (provider.employees.isEmpty) {
            return EmptyStateWidget(
              message: AppLocalizations.of(context)!.noEmployees,
              description: AppLocalizations.of(context)!.startAddingEmployees,
              icon: Icons.people_outline,
              actionText: AppLocalizations.of(context)!.addEmployee,
              onAction: _navigateToAddEmployee,
            );
          }

          final activeEmployees = provider.activeEmployees;
          final inactiveEmployees = provider.inactiveEmployees;
          final employeeProvider = context.read<EmployeeProvider>();

          return CustomScrollView(
            slivers: [
              if (activeEmployees.isNotEmpty)
                ..._buildSliverSection(
                  context,
                  AppLocalizations.of(context)!.activeEmployees,
                  activeEmployees,
                  employeeProvider,
                ),
              if (inactiveEmployees.isNotEmpty)
                ..._buildSliverSection(
                  context,
                  AppLocalizations.of(context)!.inactiveEmployees,
                  inactiveEmployees,
                  employeeProvider,
                ),
              // Bottom padding for FAB
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddEmployee,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addEmployee),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  List<Widget> _buildSliverSection(
    BuildContext context,
    String title,
    List<UserModel> employees,
    EmployeeProvider provider,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final employee = employees[index];
            return EmployeeCard(
              key: ValueKey(
                  '${employee.userId}_${employee.isActive}_${provider.isEmployeeFrozen(employee)}'),
              employee: employee,
              onDelete: employee.isActive
                  ? () => _showDeactivateDialog(employee)
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeDetailsScreen(employee: employee),
                  ),
                );
              },
            );
          },
          childCount: employees.length,
        ),
      ),
    ];
  }
}
