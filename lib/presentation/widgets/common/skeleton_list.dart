import 'package:flutter/material.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_card.dart';

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;

  const SkeletonList({
    required this.itemCount,
    required this.itemHeight,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap:
          true, // Fix: Added shrinkWrap to ensure the ListView takes only the space it needs.
      physics:
          const NeverScrollableScrollPhysics(), // Fix: Disabled scrolling on the ListView to avoid conflicts with parent scroll views.
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => SkeletonCard(height: itemHeight),
    );
  }
}
