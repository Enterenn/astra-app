import 'package:flutter/material.dart';

import '../widgets/tab_placeholder_body.dart';

/// Profil tab placeholder — full UI in Story 5.11.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderBody(
      title: 'Profil',
      placeholder:
          'Informations and appearance settings will appear here.',
    );
  }
}
