import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_pressable.dart';

/// Three-tab floating pill navigation (UX §2.1, Story 5.7 / 10.1).
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
      label: 'STEPS',
      regularIcon: PhosphorIconsRegular.sneakerMove,
      fillIcon: PhosphorIconsFill.sneakerMove,
    ),
    _NavTab(
      label: 'TRENDS',
      regularIcon: PhosphorIconsRegular.chartBar,
      fillIcon: PhosphorIconsFill.chartBar,
    ),
    _NavTab(
      label: 'MENU',
      regularIcon: PhosphorIconsRegular.list,
      fillIcon: PhosphorIconsFill.list,
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
          bottom: AstraSpacing.kBottomNavBottomOffset,
        ),
        child: SizedBox(
          height: AstraSpacing.kBottomNavBarHeight,
          width: double.infinity,
          child: Center(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _tabs.length; i++) ...[
                          if (i > 0)
                            const SizedBox(
                              width: AstraSpacing.kBottomNavItemGap,
                            ),
                          _NavItem(
                            tab: _tabs[i],
                            selected: selectedIndex == i,
                            squircleFill: squircleFill,
                            onTap: () => onSelected(i),
                          ),
                        ],
                      ],
                    ),
                  ),
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
      fontWeight: FontWeight.w700,
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
        ? ClipPath(
            clipper: const _BottomNavSquircleClipper(
              radius: AstraSpacing.kBottomNavSquircleRadius,
            ),
            child: ColoredBox(
              color: squircleFill,
              child: hitTarget,
            ),
          )
        : hitTarget;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: AstraPressable(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
          child: SizedBox(
            height: AstraSpacing.kBottomNavItemSize,
            width: AstraSpacing.kBottomNavItemSize,
            child: Center(child: squircleChild),
          ),
        ),
      ),
    );
  }
}

/// Native squircle mask for the active nav tab (Story 17-3, REF-16).
class _BottomNavSquircleClipper extends CustomClipper<Path> {
  const _BottomNavSquircleClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
    ).getOuterPath(rect);
  }

  @override
  bool shouldReclip(covariant _BottomNavSquircleClipper oldClipper) =>
      oldClipper.radius != radius;
}
