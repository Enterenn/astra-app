import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../widgets/menu_nav_row.dart';
import '../widgets/section_card.dart';

enum MenuHubDestination { profile, data, settings, about }

/// Menu hub listing secondary destinations (Profile, Data, Settings, About).
class MenuHubScreen extends StatelessWidget {
  const MenuHubScreen({
    this.onDestinationSelected,
    super.key,
  });

  final ValueChanged<MenuHubDestination>? onDestinationSelected;

  void _onDestinationSelected(MenuHubDestination destination) {
    onDestinationSelected?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          label: l10n.menuTitle,
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
                  l10n.menuTitle,
                  style: AstraTypography.screenTitleFor(colors),
                ),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                SectionCard(
                  headline: l10n.menuSectionInformations,
                  child: Column(
                    children: [
                      MenuNavRow(
                        label: l10n.menuProfile,
                        onTap: () => _onDestinationSelected(
                          MenuHubDestination.profile,
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      MenuNavRow(
                        label: l10n.menuData,
                        onTap: () =>
                            _onDestinationSelected(MenuHubDestination.data),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                SectionCard(
                  headline: l10n.menuOther,
                  child: Column(
                    children: [
                      MenuNavRow(
                        label: l10n.menuSettings,
                        onTap: () => _onDestinationSelected(
                          MenuHubDestination.settings,
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      MenuNavRow(
                        label: l10n.menuAbout,
                        onTap: () =>
                            _onDestinationSelected(MenuHubDestination.about),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
