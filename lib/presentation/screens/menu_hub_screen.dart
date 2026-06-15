import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../widgets/menu_nav_row.dart';
import '../widgets/section_card.dart';

enum MenuHubDestination { profile, data, settings, about }

/// Menu hub listing secondary destinations (Profile, Data, Settings, About).
class MenuHubScreen extends StatelessWidget {
  const MenuHubScreen({super.key});

  static const _kScreenTitle = 'Menu';

  void _onDestinationSelected(MenuHubDestination destination) {}

  @override
  Widget build(BuildContext context) {
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
          label: _kScreenTitle,
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
                  _kScreenTitle,
                  style: AstraTypography.screenTitleFor(colors),
                ),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                SectionCard(
                  headline: 'Informations',
                  child: Column(
                    children: [
                      MenuNavRow(
                        label: 'Profile',
                        onTap: () => _onDestinationSelected(
                          MenuHubDestination.profile,
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      MenuNavRow(
                        label: 'Data',
                        onTap: () =>
                            _onDestinationSelected(MenuHubDestination.data),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                SectionCard(
                  headline: 'Other',
                  child: Column(
                    children: [
                      MenuNavRow(
                        label: 'Settings',
                        onTap: () => _onDestinationSelected(
                          MenuHubDestination.settings,
                        ),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      MenuNavRow(
                        label: 'About',
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
