import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_cubit.dart';
import '../cubits/today_state.dart';
import '../widgets/goal_ring.dart';
import '../widgets/source_chip.dart';
import '../widgets/status_banner.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    required this.onNavigateToMyData,
    super.key,
  });

  final VoidCallback onNavigateToMyData;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<TodayCubit, TodayState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isStale)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AstraSpacing.kScreenHorizontalPadding,
                      AstraSpacing.kSpaceSm,
                      AstraSpacing.kScreenHorizontalPadding,
                      AstraSpacing.kSpaceSm,
                    ),
                    child: StatusBanner(
                      variant: StatusBannerVariant.staleCompact,
                      onTap: onNavigateToMyData,
                    ),
                  ),
                Expanded(
                  flex: 55,
                  child: Center(
                    child: GoalRing(state: state),
                  ),
                ),
                Expanded(
                  flex: 45,
                  child: Column(
                    children: [
                      const SourceChip(),
                      if (state.status == TodayStatus.noPermission) ...[
                        const SizedBox(height: AstraSpacing.kSpaceMd),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          child: Text(
                            'Open settings to allow step access',
                            style: AstraTypography.captionFor(colors),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
