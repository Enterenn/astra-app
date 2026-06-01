import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import 'history_screen.dart';
import 'my_data_screen.dart';
import 'today_screen.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  static const _labels = ['Today', 'History', 'My Data'];
  static const _icons = [
    Icons.circle_outlined,
    Icons.bar_chart_outlined,
    Icons.shield_outlined,
  ];
  static const _screens = [TodayScreen(), HistoryScreen(), MyDataScreen()];

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.borderDefault)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
          ],
        ),
      ),
    );
  }
}
