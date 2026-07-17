import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/l10n/l10n_date_labels.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/widgets/week_progress_row.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final colors = AstraColors.light(preset: AstraAccentPreset.orange);
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpRow(
    WidgetTester tester,
    List<WeekDayStatus> days,
    DateTime selectedLocalDay, {
    void Function(DateTime day)? onDayTap,
  }) async {
    await tester.pumpWidget(
      TestMaterialApp(
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

  String expectedLabel(WeekDayStatus status) {
    final weekdayLabel = l10n.weekdayPillLabel(status.localDay);
    if (status.isFuture) {
      return l10n.todayWeekDaySemantics(weekdayLabel, status.dayNumber);
    }
    final goalStatus = status.goalMet
        ? l10n.chartGoalStatusMet
        : l10n.todayWeekDayGoalNotMet;
    return l10n.todayWeekDaySemanticsWithStatus(
      weekdayLabel,
      status.dayNumber,
      goalStatus,
    );
  }

  testWidgets('renders localized weekday pill labels in French', (tester) async {
    final wednesday = DateTime.utc(2026, 6, 3);
    await tester.pumpWidget(
      TestMaterialApp(
        locale: const Locale('fr'),
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: WeekProgressRow(
            days: [
              day(
                localDay: wednesday,
                label: 'WED',
                dayNumber: 3,
                isToday: true,
              ),
            ],
            selectedLocalDay: wednesday,
            onDayTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MER'), findsOneWidget);
    expect(find.text('WED'), findsNothing);
  });

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

  testWidgets('future day hides dot', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 4),
        label: 'THU',
        dayNumber: 4,
        isFuture: true,
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

  testWidgets('past day number uses bold 16px text primary', (tester) async {
    final selectedDay = DateTime.utc(2026, 6, 2);
    await pumpRow(tester, [
      day(localDay: selectedDay, label: 'TUE', dayNumber: 2),
    ], selectedDay);

    final numberText = tester.widget<Text>(find.text('2'));
    expect(numberText.style?.color, colors.textPrimary);
    expect(numberText.style?.fontSize, 16);
    expect(numberText.style?.fontWeight, FontWeight.w900);
  });

  testWidgets('future day number uses neutral gray', (tester) async {
    await pumpRow(tester, [
      day(
        localDay: DateTime.utc(2026, 6, 4),
        label: 'THU',
        dayNumber: 4,
        isFuture: true,
      ),
    ], DateTime.utc(2026, 6, 3));

    final numberText = tester.widget<Text>(find.text('4'));
    expect(numberText.style?.color, colors.neutralGray);
    expect(numberText.style?.fontSize, 16);
    expect(numberText.style?.fontWeight, FontWeight.w900);
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
    final handle = tester.ensureSemantics();
    final selectedDay = DateTime.utc(2026, 6, 2);
    final otherDay = DateTime.utc(2026, 6, 3);
    final selectedStatus = day(
      localDay: selectedDay,
      label: 'TUE',
      dayNumber: 2,
    );
    final otherStatus = day(
      localDay: otherDay,
      label: 'WED',
      dayNumber: 3,
      isToday: true,
    );
    await pumpRow(tester, [selectedStatus, otherStatus], selectedDay);

    final selected = tester.getSemantics(
      find.bySemanticsLabel(expectedLabel(selectedStatus)),
    );
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);

    final unselected = tester.getSemantics(
      find.bySemanticsLabel(expectedLabel(otherStatus)),
    );
    expect(unselected.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('past goal-met pill label includes identity and met status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final status = day(
      localDay: DateTime.utc(2026, 6, 2),
      label: 'TUE',
      dayNumber: 2,
      goalMet: true,
    );
    await pumpRow(tester, [status], DateTime.utc(2026, 6, 3));

    final label = expectedLabel(status);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(label, contains(l10n.weekdayPillLabel(status.localDay)));
    expect(label, contains('2'));
    expect(label, contains(l10n.chartGoalStatusMet));
    handle.dispose();
  });

  testWidgets(
    'today and selected goal-met pills announce status without accent dot',
    (tester) async {
      final handle = tester.ensureSemantics();
      final today = DateTime.utc(2026, 6, 3);
      final selectedPast = DateTime.utc(2026, 6, 2);
      final todayStatus = day(
        localDay: today,
        label: 'WED',
        dayNumber: 3,
        isToday: true,
        goalMet: true,
      );
      final selectedStatus = day(
        localDay: selectedPast,
        label: 'TUE',
        dayNumber: 2,
        goalMet: true,
      );
      await pumpRow(tester, [selectedStatus, todayStatus], selectedPast);

      expect(
        find.bySemanticsLabel(expectedLabel(todayStatus)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(expectedLabel(selectedStatus)),
        findsOneWidget,
      );
      expect(
        expectedLabel(todayStatus),
        contains(l10n.chartGoalStatusMet),
      );
      expect(
        expectedLabel(selectedStatus),
        contains(l10n.chartGoalStatusMet),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNothing,
      );
      handle.dispose();
    },
  );

  testWidgets('past goal-not-met pill label includes not-met status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final status = day(
      localDay: DateTime.utc(2026, 6, 2),
      label: 'TUE',
      dayNumber: 2,
    );
    await pumpRow(tester, [status], DateTime.utc(2026, 6, 3));

    final label = expectedLabel(status);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(label, contains(l10n.todayWeekDayGoalNotMet));
    handle.dispose();
  });

  testWidgets('future pill label has no goal status fragment', (tester) async {
    final handle = tester.ensureSemantics();
    final status = day(
      localDay: DateTime.utc(2026, 6, 4),
      label: 'THU',
      dayNumber: 4,
      isFuture: true,
      goalMet: true,
    );
    await pumpRow(tester, [status], DateTime.utc(2026, 6, 3));

    final label = expectedLabel(status);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(label, isNot(contains(l10n.chartGoalStatusMet)));
    expect(label, isNot(contains(l10n.todayWeekDayGoalNotMet)));
    handle.dispose();
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
