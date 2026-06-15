import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/profile_state.dart';
import '../cubits/theme_cubit.dart';
import '../cubits/theme_state.dart';
import '../cubits/units_cubit.dart';
import '../cubits/units_state.dart';
import '../widgets/accent_preset_selector.dart';
import '../widgets/secondary_screen_shell.dart';
import '../widgets/section_card.dart';
import '../widgets/settings_preference_row.dart';
import '../widgets/theme_selector.dart';
import '../widgets/unit_option_picker_sheet.dart';

/// Settings destination — Units, Notifications, and Theme controls (Story 10.6).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecondaryScreenShell(
      title: 'Settings',
      child: _SettingsScreenBody(),
    );
  }
}

class _SettingsScreenBody extends StatelessWidget {
  const _SettingsScreenBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
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

        return const _SettingsScrollBody();
      },
    );
  }
}

Future<void> _pickDistanceUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required DistanceDisplayUnit selected,
}) async {
  final picked = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
    context: context,
    title: 'Distance',
    options: DistanceDisplayUnit.values,
    labelFor: (unit) => unit.displayLabel,
    selected: selected,
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setDistanceUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update unit preference')),
    );
  }
}

Future<void> _pickWeightUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required WeightDisplayUnit selected,
}) async {
  final picked = await showUnitOptionPickerSheet<WeightDisplayUnit>(
    context: context,
    title: 'Weight',
    options: WeightDisplayUnit.values,
    labelFor: (unit) => unit.displayLabel,
    selected: selected,
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setWeightUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update unit preference')),
    );
  }
}

Future<void> _pickHeightUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required HeightDisplayUnit selected,
}) async {
  final picked = await showUnitOptionPickerSheet<HeightDisplayUnit>(
    context: context,
    title: 'Height',
    options: HeightDisplayUnit.values,
    labelFor: (unit) => unit.displayLabel,
    selected: selected,
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setHeightUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update unit preference')),
    );
  }
}

class _SettingsScrollBody extends StatelessWidget {
  const _SettingsScrollBody();

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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AstraSpacing.kSpaceSm,
        horizontalPadding,
        bottomScrollPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<UnitsCubit, UnitsState>(
            builder: (context, unitsState) {
              final unitsCubit = context.read<UnitsCubit>();

              return SectionCard(
                headline: 'Units',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsPreferenceRow(
                      label: 'Distance',
                      valueLabel: unitsState.distanceUnit.displayLabel,
                      onTap: () => _pickDistanceUnit(
                        context,
                        unitsCubit: unitsCubit,
                        selected: unitsState.distanceUnit,
                      ),
                    ),
                    SettingsPreferenceRow(
                      label: 'Weight',
                      valueLabel: unitsState.weightUnit.displayLabel,
                      onTap: () => _pickWeightUnit(
                        context,
                        unitsCubit: unitsCubit,
                        selected: unitsState.weightUnit,
                      ),
                    ),
                    SettingsPreferenceRow(
                      label: 'Height',
                      valueLabel: unitsState.heightUnit.displayLabel,
                      onTap: () => _pickHeightUnit(
                        context,
                        unitsCubit: unitsCubit,
                        selected: unitsState.heightUnit,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Notifications',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Receive Goal notifications',
                    style: AstraTypography.body(context),
                  ),
                ),
                Switch(
                  value: profileState.goalNotificationsEnabled,
                  activeTrackColor: colors.accentPrimary.withValues(alpha: 0.5),
                  activeThumbColor: colors.accentPrimary,
                  onChanged: (enabled) async {
                    final saved =
                        await profileCubit.setGoalNotificationsEnabled(
                          enabled,
                        );
                    if (!saved && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update notification setting',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          SectionCard(
            headline: 'Theme',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocBuilder<ThemeCubit, ThemeState>(
                  builder: (context, themeState) {
                    return ThemeSelector(
                      selected: themeState.preference,
                      onChanged: (preference) => context
                          .read<ThemeCubit>()
                          .setThemePreference(preference),
                    );
                  },
                ),
                const SizedBox(height: AstraSpacing.kSpaceLg),
                BlocBuilder<ThemeCubit, ThemeState>(
                  builder: (context, themeState) {
                    return AccentPresetSelector(
                      selected: themeState.accentPreset,
                      onSelected: (preset) => context
                          .read<ThemeCubit>()
                          .setAccentPreset(preset),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
