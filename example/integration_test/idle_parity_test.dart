import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer_example/idle_parity_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Extra allowance on top of the measured read window, covering the rounding
/// each binding does on its way to whole milliseconds — nanosecond truncation
/// on one path, a seconds-valued float on another. Two milliseconds is enough
/// for both and small enough that a real disagreement still fails.
const int _roundingSlackMs = 2;

/// How many times to sample. One reading could be unlucky; a handful makes a
/// systematic offset between bindings visible while keeping the run short.
const int _rounds = 5;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Only sources whose binding actually exists take part. Until the per-platform
  // tickets land this is empty everywhere and the test below is skipped, which
  // is the intended state for the scaffolding commit.
  final implemented = idleSources().where((s) => s.isSupported).toList();

  group('idle duration parity', () {
    testWidgets(
      'every FFI source agrees with the method channel and with the others',
      (_) async {
        final channel = MethodChannelFlutterInactiveTimer();

        for (var round = 1; round <= _rounds; round++) {
          // One batch, read as tightly together as possible. The channel read is
          // first because it is the slow one — it hops to the platform thread —
          // so the FFI reads land inside the window it opens rather than after.
          final stopwatch = Stopwatch()..start();
          final readings = <String, int>{
            'method channel': await channel.getIdleDuration(),
            for (final source in implemented)
              source.name: source.idleMilliseconds(),
          };
          stopwatch.stop();

          // The tolerance is measured, not guessed. With no user input the idle
          // duration only grows, so two readings of the same underlying clock
          // can differ by at most the time between them — plus rounding. This
          // self-calibrates: a scheduling hiccup that widens the window widens
          // the allowance by exactly as much, instead of turning into a flake.
          final tolerance = stopwatch.elapsedMilliseconds + _roundingSlackMs;

          final spread = readings.values.reduce((a, b) => a > b ? a : b) -
              readings.values.reduce((a, b) => a < b ? a : b);

          expect(
            spread,
            lessThanOrEqualTo(tolerance),
            reason: 'round $round: readings disagree by ${spread}ms, more than '
                'the ${tolerance}ms this batch can account for — $readings. '
                'Note this test assumes no keyboard or mouse input during the '
                'run; real input mid-batch resets the clock and will also '
                'trip it.',
          );
        }
      },
      // Nothing to compare until a binding exists on this platform.
      skip: implemented.isEmpty,
    );

    testWidgets('the parity screen shows a row per reader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IdleParityDemo())),
      );
      // One frame to let the first channel read resolve and populate the table.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('method channel'), findsOneWidget);
      for (final source in idleSources()) {
        expect(
          find.text(source.name),
          findsOneWidget,
          reason: '${source.name} is missing from the parity screen',
        );
      }

      // A source with no binding yet must show *why* rather than a blank cell —
      // that message is the only thing pointing at the missing binding when
      // this screen is used to diagnose a platform. Assert on the thrown text
      // itself: matching the source name alone would pass on the row label even
      // if the error were never rendered.
      for (final source in idleSources().where((s) => !s.isSupported)) {
        final String thrown;
        try {
          source.idleMilliseconds();
          fail('${source.name} claims to be unsupported but did not throw');
        } on UnsupportedError catch (e) {
          thrown = '${e.message}';
        }
        expect(
          find.textContaining(thrown, findRichText: true),
          findsOneWidget,
          reason: '${source.name} should surface its own error text',
        );
      }
    });

    test('reports which sources took part', () {
      // Not an assertion so much as a record in the CI log: a parity run that
      // silently compared nothing would otherwise look identical to a passing
      // one. The ticket that chooses the macOS binding reads this output.
      debugPrint(
        'idle parity on ${Platform.operatingSystem}: '
        '${implemented.isEmpty ? 'no FFI source implemented yet' : implemented.map((s) => s.name).join(', ')}',
      );
    });
  });
}
