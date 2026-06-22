import 'package:astra_app/l10n/app_localizations.dart';
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
import '../l10n/profile_error_messages.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    final content = BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ProfileStatus.error) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(
                AstraSpacing.kScreenHorizontalPadding,
              ),
              child: Text(
                profileLoadErrorMessage(l10n, state.loadError),
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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n.profileCouldNotSaveDisplayName)),
        );
      }
    }

    Future<void> editHeight() async {
      final unitsState = context.read<UnitsCubit>().state;
      final result = await showHeightEditorSheet(
        context,
        currentHeightCm: profileState.heightCm,
        heightUnit: unitsState.heightUnit,
      );
      if (result == null || !context.mounted) {
        return;
      }
      final heightCm = result == -1 ? null : result;
      final saved = await profileCubit.updateHeightCm(heightCm);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileCouldNotSaveHeight)),
        );
      }
    }

    Future<void> editWeight() async {
      final unitsState = context.read<UnitsCubit>().state;
      final result = await showWeightEditorSheet(
        context,
        currentWeightKg: profileState.weightKg,
        weightUnit: unitsState.weightUnit,
      );
      if (result == null || !context.mounted) {
        return;
      }
      final weightKg = result == -1.0 ? null : result;
      final saved = await profileCubit.updateWeightKg(weightKg);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileCouldNotSaveWeight)),
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
              l10n.profileTitle,
              style: AstraTypography.screenTitleFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          SectionCard(
            headline: l10n.profileSectionInformations,
            child: BlocBuilder<UnitsCubit, UnitsState>(
              builder: (context, unitsState) {
                return Column(
                  children: [
                    DisplayNameEditorRow(
                      displayName: profileState.displayName,
                      onTap: editDisplayName,
                    ),
                    ProfileInfoRow(
                      label: l10n.profileHeight,
                      valueLabel: formatDisplayHeight(
                        l10n,
                        profileState.heightCm,
                        unitsState.heightUnit,
                      ),
                      onTap: editHeight,
                    ),
                    ProfileInfoRow(
                      label: l10n.profileWeight,
                      valueLabel: formatDisplayWeight(
                        l10n,
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
      label: l10n.profileTitle,
      child: scrollView,
    );
  }
}
