import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'chart_benchmark.dart';
import 'chart_benchmark_render_pump.dart';

/// Debug-only FAB for test/widget harnesses to run KPI-01 on a physical device.
///
/// **Not imported from production `lib/`** — use `flutter test test/dev/chart_benchmark_test.dart`
/// or wire this widget in a test harness only.
class ChartBenchmarkDevFab extends StatefulWidget {
  const ChartBenchmarkDevFab({required this.deps, super.key});

  final AppDependencies deps;

  @override
  State<ChartBenchmarkDevFab> createState() => _ChartBenchmarkDevFabState();
}

class _ChartBenchmarkDevFabState extends State<ChartBenchmarkDevFab> {
  bool _running = false;

  Future<void> _runBenchmark() async {
    if (_running) {
      return;
    }
    setState(() => _running = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('KPI-01 running (50 iterations, ~30s)…'),
        duration: Duration(seconds: 30),
      ),
    );

    final pumpChart = createOverlayStepBarChartPump(context);

    try {
      final result = await runDevChartBenchmark(
        repository: widget.deps.stepRepository,
        clock: widget.deps.timeProvider,
        db: widget.deps.stepRepository.db,
        userPreferences: widget.deps.userPreferences,
        pumpChart: pumpChart,
        profile: ChartBenchmarkProfile.fullStack,
        assertPassGate: false,
      );

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'KPI-01 ${result.passed ? "PASS" : "FAIL"}: '
            'total p95=${result.totalP95Ms.toStringAsFixed(1)}ms '
            '(see console [KPI-01] log)',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('KPI-01 benchmark failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('KPI-01 error: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'kpi01_benchmark',
      onPressed: _running ? null : _runBenchmark,
      tooltip: 'Run KPI-01 benchmark',
      child: _running
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(PhosphorIconsRegular.speedometer),
    );
  }
}
