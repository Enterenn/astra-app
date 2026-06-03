import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

enum StatusBannerVariant {
  /// Today compact stale line (~40dp, single line).
  staleCompact,

  /// My Data full stale banner.
  staleFull,

  /// iOS backfill info tone.
  info,

  /// Action error with optional custom copy (My Data export/import).
  error,
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.variant,
    this.isIos = false,
    this.message,
    this.onTap,
    super.key,
  });

  final StatusBannerVariant variant;
  final bool isIos;
  final String? message;
  final VoidCallback? onTap;

  static const _kAccentWidth = 3.0;
  static const _kCompactMinHeight = 40.0;

  String get _copy => switch (variant) {
    StatusBannerVariant.staleCompact => 'Steps may be delayed — see My Data',
    StatusBannerVariant.staleFull => isIos
        ? 'No new steps in 4+ hours. Steps update when you open the app on this device.'
        : 'No new steps in 12+ hours. Background collection may be delayed on this device.',
    StatusBannerVariant.info =>
      'Steps update when you open the app on this device.',
    StatusBannerVariant.error =>
      message ?? 'Something went wrong. Try again.',
  };

  Color _accentColor(AstraColors colors) => switch (variant) {
    StatusBannerVariant.staleCompact => colors.statusStale,
    StatusBannerVariant.staleFull => colors.statusStale,
    StatusBannerVariant.info => colors.statusInfo,
    StatusBannerVariant.error => colors.statusDanger,
  };

  EdgeInsets get _padding => switch (variant) {
    StatusBannerVariant.staleCompact => const EdgeInsets.symmetric(
      horizontal: AstraSpacing.kSpaceMd,
      vertical: AstraSpacing.kSpaceSm,
    ),
    StatusBannerVariant.staleFull => const EdgeInsets.all(AstraSpacing.kSpaceMd),
    StatusBannerVariant.info => const EdgeInsets.all(AstraSpacing.kSpaceMd),
    StatusBannerVariant.error => const EdgeInsets.all(AstraSpacing.kSpaceMd),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    final banner = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
        border: Border(
          left: BorderSide(color: _accentColor(colors), width: _kAccentWidth),
        ),
      ),
      child: ConstrainedBox(
        constraints: variant == StatusBannerVariant.staleCompact
            ? const BoxConstraints(minHeight: _kCompactMinHeight)
            : const BoxConstraints(),
        child: Padding(
          padding: _padding,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _copy,
              style: AstraTypography.captionFor(colors),
              maxLines: variant == StatusBannerVariant.staleCompact ? 1 : null,
              overflow: variant == StatusBannerVariant.staleCompact
                  ? TextOverflow.ellipsis
                  : null,
            ),
          ),
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: _copy,
        child: banner,
      );
    }

    return Semantics(
      label: _copy,
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
            child: banner,
          ),
        ),
      ),
    );
  }
}
