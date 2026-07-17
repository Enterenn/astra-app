import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';

/// Shared bar-chart loading skeleton for Trends surfaces.
///
/// Renders [barCount] skeleton bars with a top-radius-4 cap, using
/// `textMuted @ 0.18α` and an optional pulse that respects reduce-motion.
class AstraBarLoadingSkeleton extends StatefulWidget {
  const AstraBarLoadingSkeleton({
    super.key,
    required this.barCount,
    required this.barHeightAt,
    this.padding = const EdgeInsets.all(AstraSpacing.kSpaceMd),
  });

  final int barCount;
  final double Function(int index) barHeightAt;
  final EdgeInsetsGeometry padding;

  @override
  State<AstraBarLoadingSkeleton> createState() =>
      _AstraBarLoadingSkeletonState();
}

class _AstraBarLoadingSkeletonState extends State<AstraBarLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
    } else {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final controller = _pulseController;
    if (controller == null) {
      return _buildBars(colors, 1.0);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final opacityScale = 0.35 + 0.5 * controller.value;
        return _buildBars(colors, opacityScale);
      },
    );
  }

  Widget _buildBars(AstraColors colors, double opacityScale) {
    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.barCount; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AstraSpacing.kSpaceXs,
                ),
                child: Container(
                  height: widget.barHeightAt(i),
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(
                      alpha: 0.18 * opacityScale,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
