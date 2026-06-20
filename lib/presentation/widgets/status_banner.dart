import 'package:astra_app/l10n/app_localizations.dart';
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

  String _copy(AppLocalizations l10n) => switch (variant) {
    StatusBannerVariant.staleCompact => l10n.bannerStaleData,
    StatusBannerVariant.staleFull =>
      isIos ? l10n.bannerStaleFullIos : l10n.bannerStaleFullAndroid,
    StatusBannerVariant.info => l10n.bannerInfoStepsSync,
    StatusBannerVariant.error => message ?? l10n.commonErrorGeneric,
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
    final l10n = AppLocalizations.of(context);
    final copy = _copy(l10n);

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
              copy,
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
        label: copy,
        child: banner,
      );
    }

    return Semantics(
      label: copy,
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
