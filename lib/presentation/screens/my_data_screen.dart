import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/my_data_state.dart';
import '../utils/share_position_origin.dart';
import '../widgets/background_status_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/data_export_button.dart';
import '../widgets/data_import_button.dart';
import '../widgets/data_purge_button.dart';
import '../widgets/footprint_kpi_row.dart';
import '../widgets/section_card.dart';
import '../widgets/status_banner.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({
    this.showInlineTitle = true,
    super.key,
  });

  final bool showInlineTitle;

  static const _kScreenTitle = 'My Data';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    final content = MultiBlocListener(
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
                context.read<MyDataCubit>().ackImportSuccess();
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
                context.read<MyDataCubit>().ackPurgeSuccess();
              },
            ),
          ],
          child: _MyDataScreenBody(showInlineTitle: showInlineTitle),
        );

    return ColoredBox(
      color: colors.bgBase,
      child: showInlineTitle
          ? SafeArea(bottom: false, child: content)
          : content,
    );
  }
}

class _MyDataScreenBody extends StatelessWidget {
  const _MyDataScreenBody({required this.showInlineTitle});

  final bool showInlineTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final state = context.watch<MyDataCubit>().state;
    final cubit = context.read<MyDataCubit>();
    final dataActionInFlight =
        state.isExporting || state.isImporting || state.isPurging;
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;
    final nowUtc = cubit.clock.nowUtc();

    final scrollView = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AstraSpacing.kSpaceSm,
        horizontalPadding,
        bottomScrollPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showInlineTitle) ...[
            Text(
              MyDataScreen._kScreenTitle,
              style: AstraTypography.screenTitleFor(colors),
            ),
          ],
          if (state.exportErrorMessage != null) ...[
            const SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(
              variant: StatusBannerVariant.error,
              message: state.exportErrorMessage,
              onTap: () => cubit.exportAndShare(
                sharePositionOrigin: sharePositionOriginFor(context),
              ),
            ),
          ],
          if (state.importErrorMessage != null) ...[
            const SizedBox(height: AstraSpacing.kSpaceMd),
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
          ],
          if (state.purgeErrorMessage != null) ...[
            const SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(
              variant: StatusBannerVariant.error,
              message: state.purgeErrorMessage,
              onTap: () => cubit.confirmAndPurge(
                confirmedAction: PurgeConfirmAction.deleteConfirmed,
              ),
            ),
          ],
          if (state.isStale) ...[
            const SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(
              variant: StatusBannerVariant.staleFull,
              isIos: state.isIos,
            ),
          ],
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Background',
            child: state.status == MyDataStatus.loading
                ? const _SectionLoadingIndicator()
                : BackgroundStatusCard(
                    status: state.backgroundStatus,
                    lastIngestionUtc: state.lastIngestionUtc,
                    nowUtc: nowUtc,
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
        ],
      ),
    );

    if (!showInlineTitle) {
      return scrollView;
    }

    return Semantics(
      label: MyDataScreen._kScreenTitle,
      child: scrollView,
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
