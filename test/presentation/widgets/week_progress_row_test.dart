import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/widgets/week_progress_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final colors = AstraColors.light(preset: AstraAccentPreset.orange);

  Future<void> pumpRow(
    WidgetTester tester,
    List<WeekDayStatus> days,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: WeekProgressRow(days: days),
        ),
      ),
    );
    await tester.pump();
  }

  WeekDayStatus day({
    required DateTime localDay,
    required String label,
    required int dayNumber,
    bool isToday = false,
    bool isFuture = false,
    bool goalMet = false,
  }) {
    return WeekDayStatus(
      localDay: localDay,
      weekdayLabel: label,
      dayNumber: dayNumber,
      isToday: isToday,
      isFuture: isFuture,
      goalMet: goalMet,
    );
  }

  testWidgets('today pill uses accent primary fill', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 3),
        label: 'WED',
        dayNumber: 3,
        isToday: true,
      ),
    ]);

    final pill = tester.widget<Container>(
      find.descendant(
        of: find.byType(WeekProgressRow),
        matching: find.byType(Container).first,
      ),
    );
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color, colors.accentPrimary);
  });

  testWidgets('past goal met shows accent primary dot', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 2),
        label: 'TUE',
        dayNumber: 2,
        goalMet: true,
      ),
    ]);

    final dot = tester.widget<Container>(
      find.descendant(
        of: find.byType(WeekProgressRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect(
      (dot.decoration! as BoxDecoration).color,
      colors.accentPrimary,
    );
  });

  testWidgets('past goal not met hides dot', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 2),
        label: 'TUE',
        dayNumber: 2,
      ),
    ]);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
      findsNothing,
    );
  });

  testWidgets('future day shows neutral gray dot', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 4),
        label: 'THU',
        dayNumber: 4,
        isFuture: true,
      ),
    ]);

    final dot = tester.widget<Container>(
      find.descendant(
        of: find.byType(WeekProgressRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect((dot.decoration! as BoxDecoration).color, colors.neutralGray);
  });
}
