import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Horizontal ruler scroll: light momentum on fling, spring snap to ticks.
class RulerTickScrollPhysics extends ScrollPhysics {
  const RulerTickScrollPhysics({
    required this.itemExtent,
    super.parent,
  });

  final double itemExtent;

  /// Lower than default ClampingScrollPhysics friction for a longer glide.
  static const friction = 0.088;

  @override
  RulerTickScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RulerTickScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _snapPixels(double pixels, ScrollMetrics metrics) {
    final index = (pixels / itemExtent).round();
    return (index * itemExtent).clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    if (velocity.abs() >= tolerance.velocity) {
      return FrictionSimulation(
        friction,
        position.pixels,
        velocity,
        tolerance: tolerance,
      );
    }

    final target = _snapPixels(position.pixels, position);
    if ((target - position.pixels).abs() > tolerance.distance) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        0,
        tolerance: tolerance,
      );
    }

    return null;
  }
}
