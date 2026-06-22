import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/supported_app_languages.dart';
import '../cubits/locale_cubit.dart';
import '../cubits/locale_state.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/profile_state.dart';
import '../cubits/theme_cubit.dart';
import '../cubits/theme_state.dart';
import '../cubits/units_cubit.dart';
import '../cubits/units_state.dart';
import '../l10n/display_unit_l10n.dart';
import '../l10n/language_l10n.dart';
import '../l10n/profile_error_messages.dart';
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
    final l10n = AppLocalizations.of(context);

    return SecondaryScreenShell(
      title: l10n.settingsTitle,
      child: const _SettingsScreenBody(),
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

        return const _SettingsScrollBody();
      },
    );
  }
}

Future<void> _pickLanguage(
  BuildContext context, {
  required LocaleCubit localeCubit,
  required String? selected,
}) async {
  final l10n = AppLocalizations.of(context);
  const automatic = '__automatic__';
  final options = [automatic, ...SupportedAppLanguages.codes];
  final picked = await showUnitOptionPickerSheet<String>(
    context: context,
    title: l10n.settingsLanguage,
    options: options,
    labelFor: (option) => option == automatic
        ? l10n.settingsLanguageAutomatic
        : localizedLanguageName(l10n, option),
    selected: selected ?? automatic,
  );
  if (picked == null) {
    return;
  }
  final preference = picked == automatic ? null : picked;
  if (preference == selected || !context.mounted) {
    return;
  }
  final saved = await localeCubit.setLanguagePreference(preference);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsLanguageUpdateError)),
    );
  }
}

Future<void> _pickDistanceUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required DistanceDisplayUnit selected,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
    context: context,
    title: l10n.settingsDistance,
    options: DistanceDisplayUnit.values,
    labelFor: (unit) => localizedDistanceUnitPreferenceLabel(l10n, unit),
    selected: selected,
  );
  if (picked == null || picked == selected || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setDistanceUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsUnitPreferenceUpdateError)),
    );
  }
}

Future<void> _pickWeightUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required WeightDisplayUnit selected,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showUnitOptionPickerSheet<WeightDisplayUnit>(
    context: context,
    title: l10n.settingsWeight,
    options: WeightDisplayUnit.values,
    labelFor: (unit) => localizedWeightUnitPreferenceLabel(l10n, unit),
    selected: selected,
  );
  if (picked == null || picked == selected || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setWeightUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsUnitPreferenceUpdateError)),
    );
  }
}

Future<void> _pickHeightUnit(
  BuildContext context, {
  required UnitsCubit unitsCubit,
  required HeightDisplayUnit selected,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showUnitOptionPickerSheet<HeightDisplayUnit>(
    context: context,
    title: l10n.settingsHeight,
    options: HeightDisplayUnit.values,
    labelFor: (unit) => localizedHeightUnitPreferenceLabel(l10n, unit),
    selected: selected,
  );
  if (picked == null || picked == selected || !context.mounted) {
    return;
  }
  final saved = await unitsCubit.setHeightUnit(picked);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsUnitPreferenceUpdateError)),
    );
  }
}

class _SettingsScrollBody extends StatelessWidget {
  const _SettingsScrollBody();

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
          BlocBuilder<LocaleCubit, LocaleState>(
            builder: (context, localeState) {
              final localeCubit = context.read<LocaleCubit>();
              return SectionCard(
                headline: l10n.settingsLanguage,
                child: SettingsPreferenceRow(
                  label: localizedLanguagePreferenceValueLabel(
                    l10n,
                    localeState.explicitLanguageCode,
                  ),
                  valueLabel: '',
                  onTap: () => _pickLanguage(
                    context,
                    localeCubit: localeCubit,
                    selected: localeState.explicitLanguageCode,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          BlocBuilder<UnitsCubit, UnitsState>(
            builder: (context, unitsState) {
              final unitsCubit = context.read<UnitsCubit>();

              return SectionCard(
                headline: l10n.settingsUnits,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsPreferenceRow(
                      label: l10n.settingsDistance,
                      valueLabel: localizedDistanceUnitPreferenceLabel(
                        l10n,
                        unitsState.distanceUnit,
                      ),
                      onTap: () => _pickDistanceUnit(
                        context,
                        unitsCubit: unitsCubit,
                        selected: unitsState.distanceUnit,
                      ),
                    ),
                    SettingsPreferenceRow(
                      label: l10n.settingsWeight,
                      valueLabel: localizedWeightUnitPreferenceLabel(
                        l10n,
                        unitsState.weightUnit,
                      ),
                      onTap: () => _pickWeightUnit(
                        context,
                        unitsCubit: unitsCubit,
                        selected: unitsState.weightUnit,
                      ),
                    ),
                    SettingsPreferenceRow(
                      label: l10n.settingsHeight,
                      valueLabel: localizedHeightUnitPreferenceLabel(
                        l10n,
                        unitsState.heightUnit,
                      ),
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
            headline: l10n.settingsNotifications,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.settingsGoalNotifications,
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
                        SnackBar(
                          content: Text(l10n.settingsNotificationUpdateError),
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
            headline: l10n.settingsTheme,
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
