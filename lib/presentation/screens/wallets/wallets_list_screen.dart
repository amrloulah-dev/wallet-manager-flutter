import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../../core/utils/debouncer.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_list.dart';
import '../../widgets/wallet/wallet_card.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class WalletsListScreen extends StatefulWidget {
  const WalletsListScreen({super.key});

  @override
  State<WalletsListScreen> createState() => _WalletsListScreenState();
}

class _WalletsListScreenState extends State<WalletsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Add listener for pagination
    _scrollController.addListener(_onScroll);

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchInitialWallets();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<WalletProvider>().fetchMoreWallets();
    }
  }

  void _navigateToAddWallet() {
    Navigator.pushNamed(context, RouteConstants.walletForm);
  }

  void _navigateToEditWallet(WalletModel wallet) {
    if (context.read<AuthProvider>().isSubscriptionExpired) {
      ToastUtils.showError(AppLocalizations.of(context)!.subscriptionExpired);
      return;
    }
    Navigator.pushNamed(context, RouteConstants.walletForm, arguments: wallet);
  }

  void _navigateToWalletDetails(String walletId) {
    Navigator.pushNamed(context, RouteConstants.walletDetails,
        arguments: walletId);
  }

  void _showDeleteDialog(WalletModel wallet) async {
    if (context.read<AuthProvider>().isSubscriptionExpired) {
      ToastUtils.showError(AppLocalizations.of(context)!.subscriptionExpired);
      return;
    }
    final walletProvider = context.read<WalletProvider>();
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.deleteWallet,
      message: AppLocalizations.of(context)!
          .deleteWalletConfirmation(wallet.phoneNumber),
      confirmText: AppLocalizations.of(context)!.delete,
      type: DialogType.danger,
    );

    if (confirmed == true) {
      final success = await walletProvider.deleteWallet(wallet.walletId);
      if (mounted) {
        if (success) {
          ToastUtils.showSuccess(
              AppLocalizations.of(context)!.walletDeletedSuccessfully);
        } else {
          ToastUtils.showError(walletProvider.errorMessage ??
              AppLocalizations.of(context)!.walletDeletionFailed);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.wallets),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: Text(AppLocalizations.of(context)!.addWallet),
        icon: const Icon(Icons.add),
        onPressed: _navigateToAddWallet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoading;
        final hasError = provider.hasError;
        final errorMessage = provider.errorMessage;
        final isLoadingMore = provider.isLoadingMore;

        if (isLoading) {
          return const SkeletonList(itemCount: 4, itemHeight: 150);
        }

        if (hasError) {
          return CustomErrorWidget(
            message: errorMessage ??
                AppLocalizations.of(context)!.somethingWentWrong,
            onRetry: () => provider.fetchInitialWallets(forceRefresh: true),
          );
        }

        final wallets = provider.wallets;
        final filteredWallets = wallets.where((wallet) {
          final search = _searchController.text.toLowerCase();
          if (search.isNotEmpty && !wallet.phoneNumber.contains(search)) {
            return false;
          }
          return true;
        }).toList();

        if (filteredWallets.isEmpty) {
          return EmptyStateWidget(
            message: AppLocalizations.of(context)!.noWalletsYet,
            description: AppLocalizations.of(context)!.startAddingWallets,
            icon: Icons.wallet_outlined,
            actionText: AppLocalizations.of(context)!.addWallet,
            onAction: _navigateToAddWallet,
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: Column(
            children: [
              _SummaryCard(wallets: filteredWallets),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filteredWallets.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredWallets.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final wallet = filteredWallets[index];
                    return WalletCard(
                      key: ValueKey(
                          '${wallet.walletId}_${wallet.balance}_${provider.isWalletFrozenSync(wallet.walletId)}'),
                      wallet: wallet,
                      isFrozen: provider.isWalletFrozenSync(wallet.walletId),
                      onTap: () => _navigateToWalletDetails(wallet.walletId),
                      onEdit: () => _navigateToEditWallet(wallet),
                      onDelete: () => _showDeleteDialog(wallet),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        keyboardType: TextInputType.phone,
        onChanged: (value) {
          _debouncer(() {
            setState(() {});
          });
        },
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchByPhoneNumber,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<WalletModel> wallets;

  const _SummaryCard({required this.wallets});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.wallet,
            label: l10n.totalWallets,
            value: wallets.length.toString(),
          ),
          _SummaryItem(
            icon: Icons.check_circle_outline,
            label: l10n.activeWallets,
            value: wallets.where((w) => w.isActive).length.toString(),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
