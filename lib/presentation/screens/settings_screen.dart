import 'package:flutter/material.dart';

import '../widgets/secondary_screen_shell.dart';

/// Settings destination stub — full layout deferred to Story 10.5.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecondaryScreenShell(
      title: 'Settings',
      child: SizedBox.shrink(),
    );
  }
}
