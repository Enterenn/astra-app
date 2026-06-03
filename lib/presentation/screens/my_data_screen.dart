import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/time/time_provider.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/my_data_state.dart';
import '../utils/share_position_origin.dart';
import '../widgets/background_status_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/data_export_button.dart';
import '../widgets/data_import_button.dart';
import '../widgets/footprint_kpi_row.dart';
import '../widgets/section_card.dart';
import '../widgets/status_banner.dart';

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
          ],
          child: BlocBuilder<MyDataCubit, MyDataState>(
            builder: (context, state) {
              final nowUtc = clock.nowUtc();
              final cubit = context.read<MyDataCubit>();

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
                                    onPressed: state.isExporting ||
                                            state.isImporting
                                        ? null
                                        : () => cubit.exportAndShare(
                                            sharePositionOrigin:
                                                sharePositionOriginFor(
                                              buttonContext,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: AstraSpacing.kSpaceSm),
                                DataImportButton(
                                  isLoading: state.isImporting,
                                  onPressed: state.isImporting ||
                                          state.isExporting
                                      ? null
                                      : () => cubit.pickAndImport(
                                          confirmImport:
                                              (csvRowCount, existingSampleCount) =>
                                                  showImportConfirmDialog(
                                            context,
                                            csvRowCount: csvRowCount,
                                            existingSampleCount:
                                                existingSampleCount,
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
            },
          ),
        ),
      ),
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
