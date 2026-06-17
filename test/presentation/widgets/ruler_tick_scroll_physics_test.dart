import 'package:astra_app/presentation/widgets/ruler_tick_scroll_physics.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RulerTickScrollPhysics', () {
    const physics = RulerTickScrollPhysics(itemExtent: 10);
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100,
      pixels: 23,
      viewportDimension: 320,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );

    test('spring-snaps to nearest tick when released with low velocity', () {
      final simulation = physics.createBallisticSimulation(metrics, 0);
      expect(simulation, isA<ScrollSpringSimulation>());
      expect((simulation! as ScrollSpringSimulation).x(1), 20);
    });

    test('friction simulation on fling with meaningful velocity', () {
      final simulation = physics.createBallisticSimulation(metrics, 1200);
      expect(simulation, isA<FrictionSimulation>());
    });
  });
}
