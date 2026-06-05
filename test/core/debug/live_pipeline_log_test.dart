import 'package:astra_app/core/debug/live_pipeline_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    resetLivePipelineLogThrottleForTests();
    livePipelineLogForceDisabled = false;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  tearDown(() {
    livePipelineLogForceDisabled = false;
    resetLivePipelineLogThrottleForTests();
  });

  test('livePipelineLog respects force disable flag', () {
    var printed = false;
    debugPrint = (String? message, {int? wrapWidth}) {
      printed = true;
    };
    livePipelineLogForceDisabled = true;

    livePipelineLog('test', 'hello');

    expect(printed, isFalse);
  });

  test('livePipelineLog throttles repeated messages', () {
    final messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };

    livePipelineLog(
      'monitor',
      'emit',
      details: {'total': 100},
      minInterval: const Duration(seconds: 5),
    );
    livePipelineLog(
      'monitor',
      'emit',
      details: {'total': 101},
      minInterval: const Duration(seconds: 5),
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains(kLivePipelineLogTag));
    expect(messages.single, contains('monitor: emit'));
    expect(messages.single, contains('total=100'));
  });
}
