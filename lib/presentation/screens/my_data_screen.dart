import 'package:flutter/material.dart';

import '../widgets/tab_placeholder_body.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderBody(
      title: 'My Data',
      placeholder:
          'Data footprint, export, and settings will appear here.',
    );
  }
}
