import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/time/time_provider.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/my_data_state.dart';
import '../widgets/background_status_card.dart';
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
        child: BlocBuilder<MyDataCubit, MyDataState>(
          builder: (context, state) {
            final nowUtc = clock.nowUtc();

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
                ],
              ),
            );
          },
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
