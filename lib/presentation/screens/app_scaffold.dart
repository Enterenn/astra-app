import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Center(
        child: Text(
          _labels[_selectedIndex],
          style: Theme.of(context).textTheme.headlineMedium,
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
