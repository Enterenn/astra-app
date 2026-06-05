import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../widgets/astra_button.dart';
import 'onboarding_progress_indicator.dart';

class OnboardingDisplayNamePage extends StatefulWidget {
  const OnboardingDisplayNamePage({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function({String? displayName}) onComplete;

  @override
  State<OnboardingDisplayNamePage> createState() =>
      _OnboardingDisplayNamePageState();
}

class _OnboardingDisplayNamePageState extends State<OnboardingDisplayNamePage> {
  late final TextEditingController _nameController;
  var _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _trimmedName() {
    final trimmed = _nameController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _finish({required bool withName}) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onComplete(
        displayName: withName ? _trimmedName() : null,
      );
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final cubit = context.watch<OnboardingCubit>();
    final isCompleting =
        _isCompleting || cubit.state.status == OnboardingStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isCompleting ? null : cubit.previousStep,
              icon: Icon(PhosphorIconsRegular.arrowLeft, color: colors.textPrimary),
              tooltip: 'Back',
            ),
            const Expanded(
              child: OnboardingProgressIndicator(currentStep: 3, totalSteps: 4),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: AstraSpacing.kSpaceLg),
        Text(
          'What should we call you?',
          style: AstraTypography.titleFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        Text(
          'Optional. Stored only on this device.',
          style: AstraTypography.bodyFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceXl),
        TextField(
          controller: _nameController,
          maxLength: kMaxDisplayNameLength,
          decoration: InputDecoration(
            labelText: 'First name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              borderSide: BorderSide(color: colors.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              borderSide: BorderSide(color: colors.borderDefault),
            ),
          ),
        ),
        const Spacer(),
        AstraButton(
          label: 'Continue',
          isLoading: isCompleting,
          onPressed: isCompleting ? null : () => _finish(withName: true),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        AstraButton(
          label: 'Continue without name',
          variant: AstraButtonVariant.secondary,
          onPressed: isCompleting ? null : () => _finish(withName: false),
        ),
      ],
    );
  }
}
