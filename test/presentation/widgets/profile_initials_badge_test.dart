import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/profile_initials_badge.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileInitialsBadge', () {
    Future<void> pumpBadge(
      WidgetTester tester, {
      String? displayName,
      VoidCallback? onTap,
      bool enabled = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: ProfileInitialsBadge(
              displayName: displayName,
              onTap: onTap,
              enabled: enabled,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows initials when display name is set', (tester) async {
      await pumpBadge(tester, displayName: 'Marie Dupont', onTap: () {});

      expect(find.text('MD'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('shows placeholder icon when display name is unset', (
      tester,
    ) async {
      await pumpBadge(tester, displayName: null, onTap: () {});

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('?'), findsNothing);
      expect(find.text('U'), findsNothing);
    });

    testWidgets('semantics label includes initials when set', (tester) async {
      await pumpBadge(tester, displayName: 'Alex', onTap: () {});

      final semantics = tester.getSemantics(find.byType(ProfileInitialsBadge));
      expect(semantics.label, contains('Profile, A'));
    });

    testWidgets('semantics label for placeholder when no name', (tester) async {
      await pumpBadge(tester, displayName: '   ', onTap: () {});

      final semantics = tester.getSemantics(find.byType(ProfileInitialsBadge));
      expect(semantics.label, contains('Profile, no name set'));
    });

    testWidgets('disabled badge does not invoke onTap', (tester) async {
      var tapped = false;
      await pumpBadge(
        tester,
        displayName: 'Alex',
        enabled: false,
        onTap: () => tapped = true,
      );

      final badge = tester.widget<ProfileInitialsBadge>(
        find.byType(ProfileInitialsBadge),
      );
      expect(badge.onTap, isNotNull);
      expect(badge.enabled, isFalse);

      final semantics = tester.getSemantics(find.byType(ProfileInitialsBadge));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);

      await tester.tap(find.byType(ProfileInitialsBadge));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('enabled badge invokes onTap', (tester) async {
      var tapped = false;
      await pumpBadge(
        tester,
        displayName: 'Alex',
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(ProfileInitialsBadge));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
