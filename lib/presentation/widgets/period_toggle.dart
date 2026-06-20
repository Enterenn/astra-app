import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../cubits/history_state.dart';
import 'astra_segmented_control.dart';

class PeriodToggle extends StatelessWidget {
  const PeriodToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final HistoryPeriod selected;
  final ValueChanged<HistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AstraSegmentedControl<HistoryPeriod>(
      options: [
        AstraSegmentOption(
          value: HistoryPeriod.days7,
          label: l10n.trendsPeriod7Days,
        ),
        AstraSegmentOption(
          value: HistoryPeriod.days30,
          label: l10n.trendsPeriod30Days,
        ),
        AstraSegmentOption(
          value: HistoryPeriod.months12,
          label: l10n.trendsPeriod12Months,
        ),
      ],
      selected: selected,
      onChanged: onChanged,
      semanticsHint: l10n.trendsChartRangeSemantics,
    );
  }
}
