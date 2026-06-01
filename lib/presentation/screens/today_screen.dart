import 'package:flutter/material.dart';

import '../widgets/tab_placeholder_body.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderBody(
      title: 'Today',
      placeholder:
          'Step tracking and your goal ring will appear here.',
    );
  }
}
