import 'package:astra_app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runSerializedLifecycleTransition', () {
    test('clears in-flight slot after successful operation', () async {
      Future<void>? inFlight;
      var ran = false;

      await runSerializedLifecycleTransition(
        readInFlight: () => inFlight,
        writeInFlight: (future) => inFlight = future,
        operation: () async {
          ran = true;
        },
      );

      expect(ran, isTrue);
      expect(inFlight, isNull);
    });

    test('clears in-flight slot and allows next operation after throw', () async {
      Future<void>? inFlight;
      var firstRan = false;
      var secondRan = false;

      await runSerializedLifecycleTransition(
        readInFlight: () => inFlight,
        writeInFlight: (future) => inFlight = future,
        operation: () async {
          firstRan = true;
          throw StateError('first transition failed');
        },
      );

      expect(firstRan, isTrue);
      expect(inFlight, isNull);

      await runSerializedLifecycleTransition(
        readInFlight: () => inFlight,
        writeInFlight: (future) => inFlight = future,
        operation: () async {
          secondRan = true;
        },
      );

      expect(secondRan, isTrue);
      expect(inFlight, isNull);
    });

    test('queued waiter runs after prior transition throws', () async {
      Future<void>? inFlight;
      var firstRan = false;
      var secondRan = false;

      final first = runSerializedLifecycleTransition(
        readInFlight: () => inFlight,
        writeInFlight: (future) => inFlight = future,
        operation: () async {
          firstRan = true;
          throw StateError('first transition failed');
        },
      );

      final second = runSerializedLifecycleTransition(
        readInFlight: () => inFlight,
        writeInFlight: (future) => inFlight = future,
        operation: () async {
          secondRan = true;
        },
      );

      await Future.wait([first, second]);

      expect(firstRan, isTrue);
      expect(secondRan, isTrue);
      expect(inFlight, isNull);
    });

    test('preserves serialization — operations never overlap', () async {
      Future<void>? inFlight;
      var concurrent = 0;
      var maxConcurrent = 0;

      Future<void> runOp(String label) {
        return runSerializedLifecycleTransition(
          readInFlight: () => inFlight,
          writeInFlight: (future) => inFlight = future,
          operation: () async {
            concurrent++;
            maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            concurrent--;
          },
        );
      }

      await Future.wait([
        runOp('a'),
        runOp('b'),
        runOp('c'),
      ]);

      expect(maxConcurrent, 1);
      expect(inFlight, isNull);
    });
  });
}
