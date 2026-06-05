import 'dart:async';

import 'package:flutter/material.dart';

/// Subtle press scale with overshoot bounce on release for tactile feedback.
///
/// Wraps an existing interactive child (Material button, [InkWell], etc.) and
/// listens to pointer events without intercepting taps.
class AstraPressable extends StatefulWidget {
  const AstraPressable({
    required this.child,
    this.enabled = true,
    this.pressedScale = defaultPressedScale,
    super.key,
  });

  static const defaultPressedScale = 0.94;
  static const releaseOvershootScale = 1.03;
  static const restScale = 1.0;

  final Widget child;
  final bool enabled;

  /// Scale factor while the pointer is down (1.0 = full size).
  final double pressedScale;

  @visibleForTesting
  static const pressDuration = Duration(milliseconds: 80);

  @visibleForTesting
  static const releaseOvershootDuration = Duration(milliseconds: 180);

  @visibleForTesting
  static const releaseSettleDuration = Duration(milliseconds: 220);

  @visibleForTesting
  static const releaseDuration = Duration(milliseconds: 400);

  @override
  State<AstraPressable> createState() => _AstraPressableState();
}

class _AstraPressableState extends State<AstraPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _pointerDown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: widget.pressedScale,
      upperBound: AstraPressable.releaseOvershootScale,
      value: AstraPressable.restScale,
    );
  }

  @override
  void didUpdateWidget(covariant AstraPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pointerDown) {
      _pointerDown = false;
      _controller.value = AstraPressable.restScale;
    }
  }

  bool get _animationsEnabled {
    return widget.enabled && !MediaQuery.disableAnimationsOf(context);
  }

  void _press() {
    if (!_animationsEnabled) {
      return;
    }
    _pointerDown = true;
    _controller.stop();
    unawaited(
      _controller.animateTo(
        widget.pressedScale,
        duration: AstraPressable.pressDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _release() async {
    if (!_pointerDown) {
      return;
    }
    _pointerDown = false;
    if (!_animationsEnabled) {
      _controller.value = AstraPressable.restScale;
      return;
    }

    _controller.stop();
    await _controller.animateTo(
      AstraPressable.releaseOvershootScale,
      duration: AstraPressable.releaseOvershootDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    await _controller.animateTo(
      AstraPressable.restScale,
      duration: AstraPressable.releaseSettleDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => unawaited(_release()),
      onPointerCancel: (_) => unawaited(_release()),
      child: ScaleTransition(
        scale: _controller,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
