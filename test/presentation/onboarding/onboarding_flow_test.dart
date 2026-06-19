import 'dart:async';

import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:astra_app/presentation/onboarding/onboarding_flow.dart';
import 'package:astra_app/presentation/widgets/animated_step_count.dart';
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

Finder _weightSkip() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-1')),
  matching: find.text('Skip'),
);

Finder _heightLetsGo() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-2')),
  matching: find.text("Let's Go"),
);

Finder _heightSkip() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-2')),
  matching: find.text('Skip'),
);

Future<void> _advancePastIntro(WidgetTester tester) async {
  await tester.tap(_introContinue());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('OnboardingFlow', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late AppDependencies deps;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db);
      deps = await AppDependencies.test(
        db: db,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        initialOnboardingComplete: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildFlow({
      required VoidCallback onComplete,
      OnboardingCubit Function(AppDependencies)? createCubit,
    }) {
      return MaterialApp(
        theme: buildAstraLightTheme(),
        home: OnboardingFlow(
          deps: deps,
          onComplete: onComplete,
          createCubit: createCubit,
        ),
      );
    }

    OnboardingCubit grantedCubit(AppDependencies deps) {
      return OnboardingCubit(
        userSettings: deps.userSettings,
        userHealthMetrics: deps.userHealthMetrics,
        permissionRequester: (_) async => PermissionStatus.granted,
      );
    }

    testWidgets('shows intro headline on first step', (tester) async {
      await tester.pumpWidget(buildFlow(onComplete: () {}));

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
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async {
              permissionRequestCount++;
              return PermissionStatus.granted;
            },
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pump();

      expect(permissionRequestCount, 1);
    });

    testWidgets('advances to weight step after permission resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: grantedCubit,
        ),
      );

      await _advancePastIntro(tester);

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Weight'), findsNothing);
      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsNothing,
      );
    });

    testWidgets('denied activity permission still advances to weight step', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async => PermissionStatus.denied,
          ),
        ),
      );

      await _advancePastIntro(tester);

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets(
      'denied permission on intro completes via UI skip and persists onboarding flag',
      (tester) async {
        var onCompleteCalled = false;
        OnboardingCubit? cubitRef;

        await tester.pumpWidget(
          buildFlow(
            onComplete: () => onCompleteCalled = true,
            createCubit: (deps) {
              cubitRef = OnboardingCubit(
                userSettings: deps.userSettings,
                userHealthMetrics: deps.userHealthMetrics,
                permissionRequester: (_) async => PermissionStatus.denied,
              );
              return cubitRef!;
            },
          ),
        );

        await tester.tap(_introContinue());
        await tester.pumpAndSettle();

        expect(
          cubitRef!.state.activityPermissionStatus,
          PermissionRequestStatus.denied,
        );

        await tester.tap(_weightSkip());
        await tester.pump();

        expect(
          find.text('What is your height?').hitTestable(),
          findsOneWidget,
        );

        await tester.runAsync(() async {
          await cubitRef!.skipHeight();
        });
        await tester.pump();

        expect(onCompleteCalled, isTrue);

        await tester.runAsync(() async {
          expect(await userSettings.getOnboardingComplete(), isTrue);
          expect(await userHealthMetrics.getDailyStepGoal(), 8000);
        });
      },
    );

    testWidgets('recovers Continue after permission requester throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async {
              throw Exception('platform channel failure');
            },
          ),
        ),
      );

      await _advancePastIntro(tester);

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );

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
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) => permissionCompleter.future,
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      permissionCompleter.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('back navigation moves from weight to intro', (tester) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: grantedCubit,
        ),
      );

      await _advancePastIntro(tester);

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your weight?').hitTestable(),
        findsNothing,
      );
    });

    testWidgets('back navigation moves from height to weight', (tester) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: grantedCubit,
        ),
      );

      await _advancePastIntro(tester);
      await tester.tap(_weightContinue());
      await tester.pumpAndSettle();

      expect(
        find.text('What is your height?').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your height?').hitTestable(),
        findsNothing,
      );
    });

    testWidgets('weight Continue advances to height step', (tester) async {
      await tester.pumpWidget(buildFlow(onComplete: () {}, createCubit: grantedCubit));

      await _advancePastIntro(tester);
      await tester.tap(_weightContinue());
      await tester.pumpAndSettle();

      expect(
        find.text('What is your height?').hitTestable(),
        findsOneWidget,
      );
      expect(find.text("Let's Go").hitTestable(), findsOneWidget);
    });

    testWidgets("Let's Go completes onboarding with default metrics", (
      tester,
    ) async {
      var onCompleteCalled = false;
      OnboardingCubit? cubitRef;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () => onCompleteCalled = true,
          createCubit: (deps) {
            cubitRef = grantedCubit(deps);
            return cubitRef!;
          },
        ),
      );

      await _advancePastIntro(tester);
      await tester.tap(_weightContinue());
      await tester.pump();

      await tester.runAsync(() async {
        await cubitRef!.completeWithHeight();
      });
      await tester.pump();

      expect(onCompleteCalled, isTrue);
    });

    testWidgets("Let's Go button is visible on height step", (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: grantedCubit,
        ),
      );

      await _advancePastIntro(tester);
      await tester.tap(_weightContinue());
      await tester.pump();

      expect(
        find.text('What is your height?').hitTestable(),
        findsOneWidget,
      );
      expect(_heightLetsGo().hitTestable(), findsOneWidget);
      expect(_heightSkip().hitTestable(), findsOneWidget);
    });

    testWidgets('Skip weight advances to height step', (tester) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: grantedCubit,
        ),
      );

      await _advancePastIntro(tester);
      await tester.tap(_weightSkip());
      await tester.pump();

      expect(
        find.text('What is your height?').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('unit toggle preserves canonical weight across kg and lb', (
      tester,
    ) async {
      OnboardingCubit? cubitRef;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) {
            cubitRef = grantedCubit(deps);
            return cubitRef!;
          },
        ),
      );

      await _advancePastIntro(tester);

      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is AnimatedStepCount && w.value == 154,
        ),
        findsOneWidget,
      );

      await tester.tap(_weightContinue());
      await tester.pump();

      expect(cubitRef!.state.weightKg, 70.0);
      expect(cubitRef!.state.weightDisplayUnit, WeightDisplayUnit.lb);
    });

    testWidgets('unit toggle preserves canonical height across cm and in', (
      tester,
    ) async {
      OnboardingCubit? cubitRef;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) {
            cubitRef = grantedCubit(deps);
            return cubitRef!;
          },
        ),
      );

      await _advancePastIntro(tester);
      await tester.tap(_weightContinue());
      await tester.pumpAndSettle();

      await tester.tap(find.text('in'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is AnimatedStepCount && w.value == 67,
        ),
        findsOneWidget,
      );
      expect(cubitRef!.state.heightUsesInches, isTrue);
    });
  });
}
