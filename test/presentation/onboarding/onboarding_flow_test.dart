@Tags(['slow'])
library;

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
import 'package:astra_app/presentation/widgets/astra_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/l10n_test_helper.dart';
import '../../helpers/sqflite_test_helper.dart';

Finder _introContinue() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-0')),
  matching: find.text('Start'),
);

Finder _introRetry() => find.descendant(
  of: find.byKey(const ValueKey('onboarding-step-0')),
  matching: find.text('Retry'),
);

Finder _introContinueAfterDeny() => find.descendant(
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

Future<void> _advancePastIntroAfterDeny(WidgetTester tester) async {
  await tester.tap(_introContinue());
  await tester.pumpAndSettle();
  await tester.tap(_introContinueAfterDeny());
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
      return TestMaterialApp(
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
      expect(find.text('100% offline').hitTestable(), findsOneWidget);
      expect(find.text('No account required').hitTestable(), findsOneWidget);
      expect(find.text('Your steps stay on this device.'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('intro does not request permission before Start tap', (
      tester,
    ) async {
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

      expect(permissionRequestCount, 0);
    });

    testWidgets('intro shows French trust badges when locale is fr', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          locale: const Locale('fr'),
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
          ),
        ),
      );

      expect(find.text('100 % hors ligne').hitTestable(), findsOneWidget);
      expect(find.text('Aucun compte requis').hitTestable(), findsOneWidget);
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

    testWidgets('denied activity permission stays on intro with feedback', (
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

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your weight?').hitTestable(),
        findsNothing,
      );
      expect(
        find.textContaining('Step tracking needs activity access'),
        findsOneWidget,
      );
      expect(_introRetry().hitTestable(), findsOneWidget);
      expect(_introContinueAfterDeny().hitTestable(), findsOneWidget);
    });

    testWidgets(
      'denied permission on intro completes via explicit Continue and skip',
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

        await _advancePastIntroAfterDeny(tester);

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

    testWidgets('permanentlyDenied shows Open settings and Continue only', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async =>
                PermissionStatus.permanentlyDenied,
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your weight?').hitTestable(),
        findsNothing,
      );
      expect(
        find.textContaining('Activity access is blocked in system settings')
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Open settings').hitTestable(), findsOneWidget);
      expect(_introRetry(), findsNothing);
      expect(_introContinueAfterDeny().hitTestable(), findsOneWidget);

      await tester.tap(_introContinueAfterDeny());
      await tester.pumpAndSettle();

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('Retry after reversible deny grants and advances to weight', (
      tester,
    ) async {
      var requestCount = 0;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async {
              requestCount++;
              return requestCount == 1
                  ? PermissionStatus.denied
                  : PermissionStatus.granted;
            },
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(requestCount, 1);
      expect(_introRetry().hitTestable(), findsOneWidget);

      await tester.tap(_introRetry());
      await tester.pumpAndSettle();

      expect(requestCount, 2);
      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('intro does not advance on deny without explicit Continue', (
      tester,
    ) async {
      OnboardingCubit? cubitRef;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
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

      expect(cubitRef!.state.currentStep, 0);
      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your weight?').hitTestable(),
        findsNothing,
      );
    });

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

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      expect(
        find.text('Your Health. Your Phone. Period.').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('What is your weight?').hitTestable(),
        findsNothing,
      );
      expect(
        find.textContaining("couldn't check activity access"),
        findsOneWidget,
      );

      await tester.tap(_introContinueAfterDeny());
      await tester.pumpAndSettle();

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      final retryButton = tester.widget<FilledButton>(
        find.ancestor(
          of: _introRetry(),
          matching: find.byType(FilledButton),
        ),
      );
      expect(retryButton.onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows Retry label while re-requesting after deny', (
      tester,
    ) async {
      final permissionCompleter = Completer<PermissionStatus>();
      var requestCount = 0;

      await tester.pumpWidget(
        buildFlow(
          onComplete: () {},
          createCubit: (deps) => OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
            permissionRequester: (_) async {
              requestCount++;
              if (requestCount == 1) return PermissionStatus.denied;
              return permissionCompleter.future;
            },
          ),
        ),
      );

      await tester.tap(_introContinue());
      await tester.pumpAndSettle();

      await tester.tap(_introRetry());
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is AstraButton && w.label == 'Retry' && w.isLoading,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is AstraButton && w.label == 'Start' && w.isLoading,
        ),
        findsNothing,
      );
      expect(_introContinueAfterDeny().hitTestable(), findsOneWidget);

      permissionCompleter.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();

      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
      );
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

      await _advancePastIntro(tester);
      expect(permissionRequestCount, 1);

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
      expect(_introContinue().hitTestable(), findsNothing);
      expect(_introContinueAfterDeny().hitTestable(), findsOneWidget);

      await tester.tap(_introContinueAfterDeny());
      await tester.pumpAndSettle();

      expect(permissionRequestCount, 1);
      expect(
        find.text('What is your weight?').hitTestable(),
        findsOneWidget,
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
