import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Four-tab floating pill navigation (UX §2.1, Story 5.7).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = <_NavTab>[
    _NavTab(
      label: 'TODAY',
      regularIcon: PhosphorIconsRegular.sneakerMove,
      fillIcon: PhosphorIconsFill.sneakerMove,
    ),
    _NavTab(
      label: 'TRENDS',
      regularIcon: PhosphorIconsRegular.chartBar,
      fillIcon: PhosphorIconsFill.chartBar,
    ),
    _NavTab(
      label: 'DATA',
      regularIcon: PhosphorIconsRegular.database,
      fillIcon: PhosphorIconsFill.database,
    ),
    _NavTab(
      label: 'PROFILE',
      regularIcon: PhosphorIconsRegular.user,
      fillIcon: PhosphorIconsFill.user,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final squircleFill =
        isDark ? colors.bgBase : colors.bgElevated;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AstraSpacing.kScreenHorizontalPadding,
          right: AstraSpacing.kScreenHorizontalPadding,
          bottom: AstraSpacing.kBottomNavBottomOffset,
        ),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accentPrimary,
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
            ),
            child: SizedBox(
              height: AstraSpacing.kBottomNavBarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AstraSpacing.kBottomNavHorizontalPadding,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _NavItem(
                          tab: _tabs[i],
                          selected: selectedIndex == i,
                          squircleFill: squircleFill,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.regularIcon,
    required this.fillIcon,
  });

  final String label;
  final IconData regularIcon;
  final IconData fillIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.squircleFill,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final Color squircleFill;
  final VoidCallback onTap;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final inactiveColor = colors.accentSecondary;
    final activeColor = colors.accentPrimary;
    final labelStyle = TextStyle(
      fontFamily: AstraTypography.figtree,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      height: 1.2,
    );

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? tab.fillIcon : tab.regularIcon,
          size: _iconSize,
          color: selected ? activeColor : inactiveColor,
        ),
        const SizedBox(height: AstraSpacing.kBottomNavIconLabelGap),
        Text(
          tab.label,
          style: labelStyle.copyWith(
            color: selected ? activeColor : inactiveColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final hitTarget = SizedBox(
      width: AstraSpacing.kBottomNavItemSize,
      height: AstraSpacing.kBottomNavItemSize,
      child: content,
    );

    final squircleChild = selected
        ? DecoratedBox(
            decoration: ShapeDecoration(
              color: squircleFill,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AstraSpacing.kBottomNavSquircleRadius,
                  cornerSmoothing: AstraSpacing.kBottomNavSquircleSmoothing,
                ),
              ),
            ),
            child: hitTarget,
          )
        : hitTarget;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
        child: SizedBox(
          height: AstraSpacing.kBottomNavItemSize,
          width: double.infinity,
          child: Center(child: squircleChild),
        ),
      ),
    );
  }
}
