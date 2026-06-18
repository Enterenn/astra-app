import 'dart:async';

import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'chart_benchmark.dart';

/// Pumps [StepBarChart] off-screen via [Overlay] to measure fl_chart layout cost.
ChartBenchmarkWidgetPump createOverlayStepBarChartPump(BuildContext context) {
  final overlay = Overlay.of(context);
  return ({
    required List<ChartDayAggregate> points7d,
    required List<ChartDayAggregate> points30d,
    required int dailyGoal,
    required Map<String, int> goalsByDay,
  }) async {
    await _pumpChartOverlay(
      overlay,
      points: points7d,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
    );
    await _pumpChartOverlay(
      overlay,
      points: points30d,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
    );
  };
}

Future<void> _pumpChartOverlay(
  OverlayState overlay, {
  required List<ChartDayAggregate> points,
  required int dailyGoal,
  required Map<String, int> goalsByDay,
}) async {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Offstage(
      child: SizedBox(
        width: 400,
        height: 240,
        child: StepBarChart(
          points: points,
          dailyGoal: dailyGoal,
          goalsByDay: goalsByDay,
          status: HistoryStatus.ready,
        ),
      ),
    ),
  );
  overlay.insert(entry);
  await _waitForFrame();
  entry.remove();
  entry.dispose();
}

Future<void> _waitForFrame() async {
  final completer = Completer<void>();
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  await completer.future;
}
