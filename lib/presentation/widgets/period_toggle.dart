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

  static const _options = [
    AstraSegmentOption(value: HistoryPeriod.days7, label: '7 days'),
    AstraSegmentOption(value: HistoryPeriod.days30, label: '30 days'),
    AstraSegmentOption(value: HistoryPeriod.months12, label: '12 months'),
  ];

  @override
  Widget build(BuildContext context) {
    return AstraSegmentedControl<HistoryPeriod>(
      options: _options,
      selected: selected,
      onChanged: onChanged,
      semanticsHint: 'Chart range',
    );
  }
}
