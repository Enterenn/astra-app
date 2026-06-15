import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/profile_state.dart';
import '../cubits/units_cubit.dart';
import '../cubits/units_state.dart';
import '../formatters/display_unit_formatter.dart';
import '../widgets/display_name_editor_row.dart';
import '../widgets/display_name_editor_sheet.dart';
import '../widgets/height_editor_sheet.dart';
import '../widgets/profile_info_row.dart';
import '../widgets/section_card.dart';
import '../widgets/weight_editor_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    this.showInlineTitle = true,
    super.key,
  });

  final bool showInlineTitle;

  static const _kScreenTitle = 'Profile';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    final content = BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ProfileStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(
                AstraSpacing.kScreenHorizontalPadding,
              ),
              child: Text(
                state.errorMessage ?? 'Could not load profile',
                style: AstraTypography.body(context),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return _ProfileScreenBody(showInlineTitle: showInlineTitle);
      },
    );

    return ColoredBox(
      color: colors.bgBase,
      child: showInlineTitle
          ? SafeArea(bottom: false, child: content)
          : content,
    );
  }
}

class _ProfileScreenBody extends StatelessWidget {
  const _ProfileScreenBody({required this.showInlineTitle});

  final bool showInlineTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final profileState = context.watch<ProfileCubit>().state;
    final profileCubit = context.read<ProfileCubit>();
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;

    Future<void> editDisplayName() async {
      final result = await showDisplayNameEditorSheet(
        context,
        currentName: profileState.displayName,
      );
      if (result == null || !context.mounted) {
        return;
      }
      final saved = await profileCubit.updateDisplayName(result);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save display name')),
        );
      }
    }

    Future<void> editHeight() async {
      final result = await showHeightEditorSheet(
        context,
        currentHeightCm: profileState.heightCm,
      );
      if (result == null || !context.mounted) {
        return;
      }
      final heightCm = result == -1 ? null : result;
      final saved = await profileCubit.updateHeightCm(heightCm);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save height')),
        );
      }
    }

    Future<void> editWeight() async {
      final result = await showWeightEditorSheet(
        context,
        currentWeightKg: profileState.weightKg,
      );
      if (result == null || !context.mounted) {
        return;
      }
      final weightKg = result == -1.0 ? null : result;
      final saved = await profileCubit.updateWeightKg(weightKg);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save weight')),
        );
      }
    }

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
              ProfileScreen._kScreenTitle,
              style: AstraTypography.screenTitleFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          SectionCard(
            headline: 'Informations',
            child: BlocBuilder<UnitsCubit, UnitsState>(
              builder: (context, unitsState) {
                return Column(
                  children: [
                    DisplayNameEditorRow(
                      displayName: profileState.displayName,
                      onTap: editDisplayName,
                    ),
                    ProfileInfoRow(
                      label: 'Height',
                      valueLabel: formatDisplayHeight(
                        profileState.heightCm,
                        unitsState.heightUnit,
                      ),
                      onTap: editHeight,
                    ),
                    ProfileInfoRow(
                      label: 'Weight',
                      valueLabel: formatDisplayWeight(
                        profileState.weightKg,
                        unitsState.weightUnit,
                      ),
                      onTap: editWeight,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!showInlineTitle) {
      return scrollView;
    }

    return Semantics(
      label: ProfileScreen._kScreenTitle,
      child: scrollView,
    );
  }
}
