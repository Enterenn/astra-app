import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/time/time_provider.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/my_data_state.dart';
import '../cubits/theme_cubit.dart';
import '../cubits/theme_state.dart';
import '../utils/share_position_origin.dart';
import '../widgets/background_status_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/data_export_button.dart';
import '../widgets/data_import_button.dart';
import '../widgets/data_purge_button.dart';
import '../widgets/footprint_kpi_row.dart';
import '../utils/display_name_initials.dart';
import '../widgets/display_name_editor_row.dart';
import '../widgets/display_name_editor_sheet.dart';
import '../widgets/goal_editor_row.dart';
import '../widgets/profile_initials_badge.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/section_card.dart';
import '../widgets/status_banner.dart';
import '../widgets/theme_selector.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({
    required this.clock,
    super.key,
  });

  final TimeProvider clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: MultiBlocListener(
          listeners: [
            BlocListener<MyDataCubit, MyDataState>(
              listenWhen: (previous, current) =>
                  previous.isExporting &&
                  !current.isExporting &&
                  current.exportErrorMessage == null,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export saved'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            BlocListener<MyDataCubit, MyDataState>(
              listenWhen: (previous, current) =>
                  !previous.importSuccessPending &&
                  current.importSuccessPending,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Import complete'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            BlocListener<MyDataCubit, MyDataState>(
              listenWhen: (previous, current) =>
                  !previous.purgeSuccessPending && current.purgeSuccessPending,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All local data removed'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
          child: _MyDataScreenBody(clock: clock),
        ),
      ),
    );
  }
}

class _MyDataScreenBody extends StatefulWidget {
  const _MyDataScreenBody({required this.clock});

  final TimeProvider clock;

  @override
  State<_MyDataScreenBody> createState() => _MyDataScreenBodyState();
}

class _MyDataScreenBodyState extends State<_MyDataScreenBody> {
  final GlobalKey _profileSectionKey = GlobalKey();

  Future<void> _openDisplayNameEditor(BuildContext context) async {
    final cubit = context.read<MyDataCubit>();
    final result = await showDisplayNameEditorSheet(
      context,
      currentName: context.read<MyDataCubit>().state.displayName,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final saved = await cubit.updateDisplayName(result);
    if (!context.mounted) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name could not be saved. Try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _scrollToProfileSection() {
    const scroll = Duration(milliseconds: 300);

    void scrollIfMounted() {
      if (!mounted) {
        return;
      }
      final profileContext = _profileSectionKey.currentContext;
      if (profileContext == null) {
        assert(
          false,
          'Profile section is not mounted; cannot scroll into view.',
        );
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          profileContext,
          duration: scroll,
          curve: Curves.easeInOut,
          alignment: 0.1,
        ),
      );
    }

    if (_profileSectionKey.currentContext != null) {
      scrollIfMounted();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollIfMounted());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyDataCubit>().state;
    final nowUtc = widget.clock.nowUtc();
    final cubit = context.read<MyDataCubit>();
    final dataActionInFlight =
        state.isExporting || state.isImporting || state.isPurging;
    final showProfileInitials = hasDisplayNameInitials(state.displayName);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AstraSpacing.kScreenHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AstraSpacing.kSpaceMd),
          Text('My Data', style: AstraTypography.title(context)),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          if (state.isStale) ...[
            StatusBanner(
              variant: StatusBannerVariant.staleFull,
              isIos: state.isIos,
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          if (state.exportErrorMessage != null) ...[
            StatusBanner(
              variant: StatusBannerVariant.error,
              message: state.exportErrorMessage,
              onTap: () => cubit.exportAndShare(
                sharePositionOrigin: sharePositionOriginFor(context),
              ),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          if (state.importErrorMessage != null) ...[
            StatusBanner(
              variant: StatusBannerVariant.error,
              message: state.importErrorMessage,
              onTap: () => cubit.pickAndImport(
                confirmImport: (csvRowCount, existingSampleCount) =>
                    showImportConfirmDialog(
                  context,
                  csvRowCount: csvRowCount,
                  existingSampleCount: existingSampleCount,
                ),
              ),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          if (state.purgeErrorMessage != null) ...[
            StatusBanner(
              variant: StatusBannerVariant.error,
              message: state.purgeErrorMessage,
              onTap: () => cubit.confirmAndPurge(
                confirmedAction: PurgeConfirmAction.deleteConfirmed,
              ),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: ProfileInitialsBadge(
              displayName: state.displayName,
              enabled: !dataActionInFlight,
              onTap: dataActionInFlight
                  ? null
                  : () {
                      if (showProfileInitials) {
                        _scrollToProfileSection();
                      } else {
                        unawaited(_openDisplayNameEditor(context));
                      }
                    },
            ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Background',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : BackgroundStatusCard(
                    status: state.backgroundStatus,
                    lastIngestionUtc: state.lastIngestionUtc,
                    nowUtc: nowUtc,
                    capabilities: state.capabilitySnapshot,
                    onOpenSettings: () => openAppSettings(),
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Footprint',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : FootprintKpiRow(
                    sampleCount: state.sampleCount,
                    fileSizeBytes: state.fileSizeBytes,
                    lastOptimizedUtc: state.lastOptimizedUtc,
                    nowUtc: nowUtc,
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Daily goal',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : GoalEditorRow(
                    dailyStepGoal: state.dailyStepGoal,
                    enabled: !dataActionInFlight,
                    onTap: dataActionInFlight
                        ? null
                        : () async {
                            final result = await showGoalEditorSheet(
                              context,
                              currentGoal: state.dailyStepGoal,
                            );
                            if (result == null || !context.mounted) {
                              return;
                            }
                            final saved = await cubit.updateDailyStepGoal(
                              result,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            if (!saved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Daily goal could not be saved. Try again.',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Appearance',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : BlocBuilder<ThemeCubit, ThemeState>(
                    builder: (context, themeState) {
                      return ThemeSelector(
                        selected: themeState.preference,
                        enabled: !dataActionInFlight,
                        onChanged: (preference) {
                          unawaited(
                            context
                                .read<ThemeCubit>()
                                .setThemePreference(preference),
                          );
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            key: _profileSectionKey,
            headline: 'Profile',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : DisplayNameEditorRow(
                    displayName: state.displayName,
                    enabled: !dataActionInFlight,
                    onTap: dataActionInFlight
                        ? null
                        : () => unawaited(_openDisplayNameEditor(context)),
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Your data',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Builder(
                        builder: (buttonContext) => DataExportButton(
                          label: 'Export CSV',
                          semanticsLabel: 'Export data as CSV file',
                          isLoading: state.isExporting,
                          onPressed: dataActionInFlight
                              ? null
                              : () => cubit.exportAndShare(
                                    sharePositionOrigin:
                                        sharePositionOriginFor(buttonContext),
                                  ),
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      DataImportButton(
                        isLoading: state.isImporting,
                        onPressed: dataActionInFlight
                            ? null
                            : () => cubit.pickAndImport(
                                  confirmImport:
                                      (csvRowCount, existingSampleCount) =>
                                          showImportConfirmDialog(
                                    context,
                                    csvRowCount: csvRowCount,
                                    existingSampleCount: existingSampleCount,
                                  ),
                                ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      Builder(
                        builder: (buttonContext) => DataPurgeButton(
                          isLoading: state.isPurging,
                          onPressed: dataActionInFlight
                              ? null
                              : () => _confirmAndPurge(
                                    context,
                                    cubit,
                                    shareContext: buttonContext,
                                  ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
        ],
      ),
    );
  }
}

Future<void> _confirmAndPurge(
  BuildContext context,
  MyDataCubit cubit, {
  BuildContext? shareContext,
}) async {
  final action = await showPurgeConfirmDialog(
    context,
    onExportFirst: () => cubit.exportAndShare(
      sharePositionOrigin: sharePositionOriginFor(shareContext ?? context),
    ),
  );
  if (action == PurgeConfirmAction.deleteConfirmed) {
    await cubit.confirmAndPurge(
      confirmedAction: PurgeConfirmAction.deleteConfirmed,
    );
  }
}

class _SectionLoadingIndicator extends StatelessWidget {
  const _SectionLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
