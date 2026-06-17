import 'dart:async';

import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

Finder _introContinue() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-0')),
  matching: find.text('Continue'),
);

Finder _weightContinue() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-1')),
  matching: find.text('Continue'),
);

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('OnboardingFlow', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late AppDependencies deps;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        initialOnboardingComplete: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows intro headline on first step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(deps: deps, onComplete: () {}),
        ),
      );

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Your steps stay on this device.'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('intro Continue requests activity permission', (tester) async {
      var permissionRequestCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async {
                permissionRequestCount++;
                return PermissionStatus.granted;
              },
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pump();

      expect(permissionRequestCount, 1);
    });

    testWidgets('advances to weight placeholder after permission resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async => PermissionStatus.granted,
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(find.text('Weight').hitTestable(), findsOneWidget);
      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsNothing,
      );
    });

    testWidgets('denied activity permission still advances to weight step', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async => PermissionStatus.denied,
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(find.text('Weight').hitTestable(), findsOneWidget);
    });

    testWidgets('disclaimer expand does not disable Continue', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(deps: deps, onComplete: () {}),
        ),
      );

      expect(_introContinue(), findsOneWidget);

      await tester.tap(find.text('Learn more'));
      await tester.pump();

      expect(
        find.textContaining('All data stays on this device'),
        findsOneWidget,
      );

      final continueButton = tester.widget<FilledButton>(
        find.ancestor(
          of: _introContinue(),
          matching: find.byType(FilledButton),
        ),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('recovers Continue after permission requester throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async {
                throw Exception('platform channel failure');
              },
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(find.text('Weight').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      final continueButton = tester.widget<FilledButton>(
        find.ancestor(
          of: _introContinue(),
          matching: find.byType(FilledButton),
        ),
      );
      expect(continueButton.onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows loading on Continue during permission request', (
      tester,
    ) async {
      final permissionCompleter = Completer<PermissionStatus>();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) => permissionCompleter.future,
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      permissionCompleter.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();

      expect(find.text('Weight').hitTestable(), findsOneWidget);
    });

    testWidgets('back navigation moves from weight to intro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async => PermissionStatus.granted,
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(find.text('Weight').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Weight').hitTestable(), findsNothing);
    });

    testWidgets('back navigation moves from height to weight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async => PermissionStatus.granted,
            ),
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();
      await tester.tap(_weightContinue());
      await tester.pump();

      expect(find.text('Height').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      expect(find.text('Weight').hitTestable(), findsOneWidget);
      expect(find.text('Height').hitTestable(), findsNothing);
    });

    testWidgets('invokes onComplete when onboarding finishes', (tester) async {
      var onCompleteCalled = false;
      OnboardingCubit? cubitRef;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () => onCompleteCalled = true,
            createCubit: (repo) {
              cubitRef = OnboardingCubit(
                userPreferences: repo,
                permissionRequester: (_) async => PermissionStatus.granted,
              );
              return cubitRef!;
            },
          ),
        ),
      );

      await tester.binding.runAsync(() async {
        await cubitRef!.completeOnboarding(goal: 8000);
      });
      await tester.pump();

      expect(onCompleteCalled, isTrue);
    });
  });
}
