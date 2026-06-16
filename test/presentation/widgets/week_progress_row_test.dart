import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/widgets/week_progress_row.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final colors = AstraColors.light(preset: AstraAccentPreset.orange);

  Future<void> pumpRow(
    WidgetTester tester,
    List<WeekDayStatus> days,
    DateTime selectedLocalDay, {
    void Function(DateTime day)? onDayTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: WeekProgressRow(
            days: days,
            selectedLocalDay: selectedLocalDay,
            onDayTap: onDayTap ?? (_) {},
          ),
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
    final selectedDay = DateTime.utc(2026, 6, 3);
    await pumpRow(tester, [
      day(
        localDay: selectedDay,
        label: 'WED',
        dayNumber: 3,
        isToday: true,
      ),
    ], selectedDay);

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
    ], DateTime.utc(2026, 6, 3));

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
    ], DateTime.utc(2026, 6, 3));

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
    ], DateTime.utc(2026, 6, 3));

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

  testWidgets('future day tap does not invoke callback', (tester) async {
    var tapCount = 0;
    await pumpRow(
      tester,
      [
        day(
          localDay: DateTime.utc(2026, 6, 4),
          label: 'THU',
          dayNumber: 4,
          isFuture: true,
        ),
      ],
      DateTime.utc(2026, 6, 3),
      onDayTap: (_) => tapCount++,
    );

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapCount, 0);
  });

  testWidgets('selected pill exposes semantics selected state', (tester) async {
    final selectedDay = DateTime.utc(2026, 6, 2);
    final otherDay = DateTime.utc(2026, 6, 3);
    await pumpRow(tester, [
      day(localDay: selectedDay, label: 'TUE', dayNumber: 2),
      day(localDay: otherDay, label: 'WED', dayNumber: 3, isToday: true),
    ], selectedDay);

    final selected = tester.getSemantics(find.text('2'));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);

    final unselected = tester.getSemantics(find.text('3'));
    expect(unselected.flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('tap callback emits expected localDay', (tester) async {
    DateTime? tappedDay;
    final targetDay = DateTime.utc(2026, 6, 5);
    await pumpRow(
      tester,
      [
        day(
          localDay: targetDay,
          label: 'FRI',
          dayNumber: 5,
        ),
      ],
      DateTime.utc(2026, 6, 3),
      onDayTap: (day) => tappedDay = day,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tappedDay, targetDay);
  });
}
