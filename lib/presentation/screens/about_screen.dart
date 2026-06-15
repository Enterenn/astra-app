import 'package:flutter/material.dart';

import '../widgets/secondary_screen_shell.dart';

/// About destination stub — full layout deferred to Story 10.8.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecondaryScreenShell(
      title: 'About',
      child: SizedBox.shrink(),
    );
  }
}
