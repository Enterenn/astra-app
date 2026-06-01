import 'package:flutter/material.dart';

import '../widgets/tab_placeholder_body.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderBody(
      title: 'History',
      placeholder: 'Your 7-day and 30-day charts will appear here.',
    );
  }
}
