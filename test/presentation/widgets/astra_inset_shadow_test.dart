import 'package:astra_app/presentation/widgets/astra_inset_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BorderRadiusHarness extends StatefulWidget {
  const _BorderRadiusHarness();

  @override
  State<_BorderRadiusHarness> createState() => _BorderRadiusHarnessState();
}

class _BorderRadiusHarnessState extends State<_BorderRadiusHarness> {
  BorderRadius _borderRadius = const BorderRadius.all(Radius.circular(8));

  void _useWiderRadius() {
    setState(() {
      _borderRadius = const BorderRadius.all(Radius.circular(16));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 60,
          child: AstraInsetShadowSurface(
            color: Colors.white,
            borderRadius: _borderRadius,
            child: const SizedBox.expand(),
          ),
        ),
        TextButton(
          key: const Key('widen-border-radius'),
          onPressed: _useWiderRadius,
          child: const Text('Widen'),
        ),
      ],
    );
  }
}

void main() {
  group('AstraInsetShadowSurface', () {
    testWidgets('repaints after borderRadius changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: _BorderRadiusHarness()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AstraInsetShadowSurface), findsOneWidget);

      await tester.tap(find.byKey(const Key('widen-border-radius')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AstraInsetShadowSurface), findsOneWidget);
    });
  });

  group('inset shadow cache invalidation', () {
    const size = Size(200, 60);
    const dpr = 2.0;
    const brInitial = BorderRadius.all(Radius.circular(8));
    const brUpdated = BorderRadius.all(Radius.circular(16));

    test('cache key matches size, borderRadius, and devicePixelRatio', () {
      expect(
        insetShadowCacheMatches(
          size: size,
          borderRadius: brInitial,
          devicePixelRatio: dpr,
          cachedSize: size,
          cachedBorderRadius: brInitial,
          cachedDevicePixelRatio: dpr,
          hasImage: true,
        ),
        isTrue,
      );

      expect(
        insetShadowCacheMatches(
          size: size,
          borderRadius: brUpdated,
          devicePixelRatio: dpr,
          cachedSize: size,
          cachedBorderRadius: brInitial,
          cachedDevicePixelRatio: dpr,
          hasImage: true,
        ),
        isFalse,
      );
    });

    test('painter shouldRepaint when borderRadius changes', () {
      const color = Colors.white;

      expect(
        astraInsetShadowPainterShouldRepaint(
          oldColor: color,
          newColor: color,
          oldBorderRadius: brInitial,
          newBorderRadius: brInitial,
        ),
        isFalse,
      );

      expect(
        astraInsetShadowPainterShouldRepaint(
          oldColor: color,
          newColor: color,
          oldBorderRadius: brInitial,
          newBorderRadius: brUpdated,
        ),
        isTrue,
      );
    });
  });
}
