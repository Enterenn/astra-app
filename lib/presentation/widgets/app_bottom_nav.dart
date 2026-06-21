import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

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

  static const _regularIcons = [
    PhosphorIconsRegular.sneakerMove,
    PhosphorIconsRegular.chartBar,
    PhosphorIconsRegular.list,
  ];

  static const _fillIcons = [
    PhosphorIconsFill.sneakerMove,
    PhosphorIconsFill.chartBar,
    PhosphorIconsFill.list,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.navSteps, l10n.navTrends, l10n.navMenu];
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
                        for (var i = 0; i < labels.length; i++) ...[
                          if (i > 0)
                            const SizedBox(
                              width: AstraSpacing.kBottomNavItemGap,
                            ),
                          _NavItem(
                            label: labels[i],
                            regularIcon: _regularIcons[i],
                            fillIcon: _fillIcons[i],
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.regularIcon,
    required this.fillIcon,
    required this.selected,
    required this.squircleFill,
    required this.onTap,
  });

  final String label;
  final IconData regularIcon;
  final IconData fillIcon;
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
          selected ? fillIcon : regularIcon,
          size: _iconSize,
          color: selected ? activeColor : inactiveColor,
        ),
        const SizedBox(height: AstraSpacing.kBottomNavIconLabelGap),
        Text(
          label,
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
      label: label,
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
