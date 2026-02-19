import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';

class TransactionOverlayScreen extends StatelessWidget {
  const TransactionOverlayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OverlayProvider(),
      child: const _OverlayContent(),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent({Key? key}) : super(key: key);

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  late OverlayProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<OverlayProvider>(context, listen: false);

      // Listen to overlay stream for data
      FlutterOverlayWindow.overlayListener.listen((event) {
        debugPrint("Overlay Event Received: $event");
        if (event != null) {
          _provider.loadData(event);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _provider = Provider.of<OverlayProvider>(context);

    // Error Snackbar
    if (_provider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_provider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Transaction',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: _provider.close,
                      ),
                    ],
                  ),
                  const Divider(),

                  if (_provider.isLoading &&
                      !_provider.availableWallets.isNotEmpty)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Details
                    _buildInfoRow('Amount', '${_provider.amount} EGP'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Sender', _provider.sender),
                    const SizedBox(height: 16),

                    // Wallet Dropdown
                    DropdownButtonFormField<String>(
                      value: _provider.selectedWalletId,
                      decoration: const InputDecoration(
                        labelText: 'Select Wallet',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _provider.availableWallets.map((wallet) {
                        return DropdownMenuItem<String>(
                          value: wallet['id'],
                          child: Text(wallet['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: _provider.setSelectedWallet,
                    ),
                    const SizedBox(height: 12),

                    // Commission Field
                    TextFormField(
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Commission (EGP)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: _provider.setCommission,
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _provider.isLoading
                          ? null
                          : _provider.submitTransaction,
                      child: _provider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm & Save',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
