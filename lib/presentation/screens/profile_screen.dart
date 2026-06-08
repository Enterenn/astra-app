import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/profile_state.dart';
import '../cubits/theme_cubit.dart';
import '../cubits/theme_state.dart';
import '../widgets/accent_preset_selector.dart';
import '../widgets/display_name_editor_row.dart';
import '../widgets/display_name_editor_sheet.dart';
import '../widgets/height_editor_sheet.dart';
import '../widgets/profile_info_row.dart';
import '../widgets/section_card.dart';
import '../widgets/theme_selector.dart';
import '../widgets/weight_editor_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _kScreenTitle = 'My Profile';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
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

            return const _ProfileScreenBody();
          },
        ),
      ),
    );
  }
}

class _ProfileScreenBody extends StatelessWidget {
  const _ProfileScreenBody();

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

    return Semantics(
      label: ProfileScreen._kScreenTitle,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AstraSpacing.kSpaceSm,
          horizontalPadding,
          bottomScrollPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ProfileScreen._kScreenTitle,
              style: AstraTypography.screenTitleFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            SectionCard(
              headline: 'Informations',
              child: Column(
                children: [
                  DisplayNameEditorRow(
                    displayName: profileState.displayName,
                    onTap: editDisplayName,
                  ),
                  ProfileInfoRow(
                    label: 'Height',
                    valueLabel: formatHeightCm(profileState.heightCm),
                    onTap: editHeight,
                  ),
                  ProfileInfoRow(
                    label: 'Weight',
                    valueLabel: formatWeightKg(profileState.weightKg),
                    onTap: editWeight,
                  ),
                ],
              ),
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
              headline: 'Appearance',
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
            const _ProfileVersionFooter(),
          ],
        ),
      ),
    );
  }
}

class _ProfileVersionFooter extends StatefulWidget {
  const _ProfileVersionFooter();

  @override
  State<_ProfileVersionFooter> createState() => _ProfileVersionFooterState();
}

class _ProfileVersionFooterState extends State<_ProfileVersionFooter> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final info = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.only(top: AstraSpacing.kSpaceLg),
          child: Center(
            child: Text(
              'ASTRA v${info.version} (${info.buildNumber})',
              style: AstraTypography.caption(context).copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
