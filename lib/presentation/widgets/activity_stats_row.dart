import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_state.dart';
import '../cubits/units_cubit.dart';
import '../cubits/units_state.dart';
import '../formatters/activity_metrics_formatter.dart';
import '../formatters/display_unit_formatter.dart';

/// Three-column activity stats (kcal, km/mi, walking duration).
class ActivityStatsRow extends StatelessWidget {
  const ActivityStatsRow({
    super.key,
    required this.status,
    required this.metrics,
    this.distanceDisplayUnit,
  });

  final TodayStatus status;
  final ActivityMetricsSnapshot metrics;

  /// When set, skips [UnitsCubit] lookup (useful in widget tests).
  final DistanceDisplayUnit? distanceDisplayUnit;

  static const _kLoadingPlaceholder = '—';
  static const _kZeroKcal = '0';
  static const _kZeroKm = '0.0';
  static const _kZeroDuration = '00:00:00';

  @override
  Widget build(BuildContext context) {
    if (distanceDisplayUnit != null) {
      return _buildRow(context, distanceDisplayUnit!);
    }

    return BlocBuilder<UnitsCubit, UnitsState>(
      builder: (context, unitsState) =>
          _buildRow(context, unitsState.distanceUnit),
    );
  }

  Widget _buildRow(BuildContext context, DistanceDisplayUnit distanceUnit) {
    final colors = context.astraColors;
    final l10n = AppLocalizations.of(context);
    final (kcal, distanceValue, distanceLabel, duration) =
        _formattedValues(l10n, distanceUnit);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.fire,
              value: kcal,
              label: l10n.todayStatsKcalLabel,
              colors: colors,
            ),
          ),
          _StatDivider(color: colors.accentPrimary),
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.mapPin,
              value: distanceValue,
              label: distanceLabel,
              colors: colors,
            ),
          ),
          _StatDivider(color: colors.accentPrimary),
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.clock,
              value: duration,
              colors: colors,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }

  (String, String, String, String) _formattedValues(
    AppLocalizations l10n,
    DistanceDisplayUnit distanceUnit,
  ) {
    final distanceLabel = distanceUnit == DistanceDisplayUnit.imperial
        ? l10n.todayStatsMiLabel
        : l10n.todayStatsKmLabel;

    if (status == TodayStatus.loading) {
      return (
        _kLoadingPlaceholder,
        _kLoadingPlaceholder,
        distanceLabel,
        _kLoadingPlaceholder,
      );
    }
    if (status == TodayStatus.noPermission) {
      return (
        _kZeroKcal,
        _kZeroKm,
        distanceLabel,
        _kZeroDuration,
      );
    }
    return (
      formatKcal(metrics.kcal),
      formatDisplayDistanceValue(metrics.distanceKm, distanceUnit),
      distanceLabel,
      formatWalkingDuration(metrics.walkingDuration),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: color,
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.colors,
    this.label,
    this.tabular = false,
  });

  final IconData icon;
  final String value;
  final String? label;
  final AstraColors colors;
  final bool tabular;

  TextStyle get _dataStyle => AstraTypography.captionFor(colors).copyWith(
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        fontFeatures: tabular
            ? const [FontFeature.tabularFigures()]
            : null,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: colors.neutralGray),
        const SizedBox(height: AstraSpacing.kSpaceXs),
        if (label != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: _dataStyle),
              const SizedBox(width: AstraSpacing.kSpaceXs),
              Text(label!, style: _dataStyle),
            ],
          )
        else
          Text(
            value,
            style: _dataStyle,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
