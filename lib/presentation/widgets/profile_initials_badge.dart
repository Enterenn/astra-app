import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../utils/display_name_initials.dart';

/// Circular profile affordance showing initials or a neutral placeholder icon.
class ProfileInitialsBadge extends StatelessWidget {
  const ProfileInitialsBadge({
    required this.displayName,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String? displayName;
  final VoidCallback? onTap;
  final bool enabled;

  static const double _badgeSize = 40;

  bool get _isInteractive => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final initials = initialsFromDisplayName(displayName);
    final hasInitials = initials != null && initials.isNotEmpty;

    final semanticsLabel = hasInitials
        ? 'Profile, $initials'
        : 'Profile, no name set';

    return Semantics(
      button: true,
      enabled: _isInteractive,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isInteractive ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AstraSpacing.kMinTouchTarget,
            height: AstraSpacing.kMinTouchTarget,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: _badgeSize,
                  height: _badgeSize,
                  child: Center(
                    child: hasInitials
                        ? Text(
                            initials,
                            style: AstraTypography.headline(context).copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                          )
                        : Icon(
                            Icons.person_outline,
                            color: colors.textMuted,
                            size: 22,
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
