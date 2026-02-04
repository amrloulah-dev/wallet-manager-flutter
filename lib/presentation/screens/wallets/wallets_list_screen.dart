import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../../core/utils/debouncer.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_list.dart';
import '../../widgets/wallet/wallet_card.dart';
import '../../widgets/common/add_close_animated_icon.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class WalletsListScreen extends StatefulWidget {
  const WalletsListScreen({super.key});

  @override
  State<WalletsListScreen> createState() => _WalletsListScreenState();
}

class _WalletsListScreenState extends State<WalletsListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  final _scrollController = ScrollController();
  final bool _showFilters = false;

  late AnimationController _fabAnimationController;
  bool isFabMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

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
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<WalletProvider>().fetchMoreWallets();
    }
  }

  void _toggleFabMenu() {
    setState(() {
      isFabMenuOpen = !isFabMenuOpen;
      if (isFabMenuOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _navigateToAddWallet() {
    Navigator.pushNamed(context, RouteConstants.walletForm);
  }

  void _navigateToAddBalance() {
    Navigator.pushNamed(context, RouteConstants.addBalance);
  }

  void _navigateToEditWallet(WalletModel wallet) {
    Navigator.pushNamed(context, RouteConstants.walletForm, arguments: wallet);
  }

  void _navigateToWalletDetails(String walletId) {
    Navigator.pushNamed(context, RouteConstants.walletDetails,
        arguments: walletId);
  }

  void _showDeleteDialog(WalletModel wallet) async {
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
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildSearchBar(provider),
              Expanded(
                child: _buildContent(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildSpeedDialFab(),
    );
  }

  Widget _buildContent(WalletProvider provider) {
    if (provider.isLoading) {
      return const SkeletonList(itemCount: 4, itemHeight: 150);
    }

    if (provider.hasError) {
      return CustomErrorWidget(
        message: provider.errorMessage ??
            AppLocalizations.of(context)!.somethingWentWrong,
        onRetry: provider.fetchInitialWallets,
      );
    }

    final wallets = provider.wallets.where((wallet) {
      final search = _searchController.text.toLowerCase();
      if (search.isNotEmpty && !wallet.phoneNumber.contains(search)) {
        return false;
      }
      return true;
    }).toList();

    if (wallets.isEmpty) {
      return EmptyStateWidget(
        message: AppLocalizations.of(context)!.noWalletsYet,
        description: AppLocalizations.of(context)!.startAddingWallets,
        icon: Icons.wallet_outlined,
        actionText: AppLocalizations.of(context)!.addWallet,
        onAction: _navigateToAddWallet,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchInitialWallets,
      child: Column(
        children: [
          _buildSummaryCard(wallets),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80), // Space for FAB
              itemCount: wallets.length + (provider.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == wallets.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final wallet = wallets[index];
                return WalletCard(
                  wallet: wallet,
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
  }

  Widget _buildSpeedDialFab() {
    return SizedBox(
      height: 250.0,
      width: 250.0,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          ..._buildFabOptions(),
          FloatingActionButton(
            onPressed: _toggleFabMenu,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: AppLocalizations.of(context)!.addWallet,
            child: AddCloseAnimatedIcon(
              progress: _fabAnimationController,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFabOptions() {
    final options = <Widget>[
      _FabOption(
        label: AppLocalizations.of(context)!.addBalance,
        icon: Icons.add_card_outlined,
        onPressed: _navigateToAddBalance,
        animation: _fabAnimationController,
        translation: const Offset(0, -65),
      ),
      _FabOption(
        label: AppLocalizations.of(context)!.addWallet,
        icon: Icons.account_balance_wallet_outlined,
        onPressed: _navigateToAddWallet,
        animation: _fabAnimationController,
        translation: const Offset(0, -130),
      ),
    ];

    return options;
  }

  Widget _buildSearchBar(WalletProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

  Widget _buildSummaryCard(List<WalletModel> wallets) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.wallet,
            label: AppLocalizations.of(context)!.totalWallets,
            value: wallets.length.toString(),
          ),
          _SummaryItem(
            icon: Icons.check_circle_outline,
            label: AppLocalizations.of(context)!.activeWallets,
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

class _FabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Animation<double> animation;
  final Offset translation;

  const _FabOption({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.animation,
    required this.translation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            translation.dx * animation.value,
            translation.dy * animation.value,
          ),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Card(
            elevation: 4,
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(label,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.surface(context))),
            ),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.small(
            onPressed: onPressed,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface(context),
            heroTag: null,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
