import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_inactive_timer_example/idle_source_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The coarsest step this platform's idle clock takes, plus the millisecond
/// rounding on the way out.
///
/// On Windows the system tick is **15.625 ms** by default and the last-input
/// time moves only on that tick, so a reading can be a full step stale while
/// almost no time has passed. This is measured, not assumed: while the parity
/// harness still existed, leaving this out produced failures of exactly 15 and
/// 16 ms — one tick — with no other cause.
///
/// macOS reports nanoseconds, so there is no coarse tick to absorb; two covers
/// the millisecond conversion plus the measured window's own truncation to
/// whole milliseconds.
int get _clockGranularityMs => Platform.isWindows ? 16 : 2;

/// How long to hold still and watch the idle clock advance. Long enough that a
/// wrong unit is unmistakable, short enough that the window is unlikely to be
/// interrupted.
const Duration _observation = Duration(milliseconds: 600);

/// How many attempts before giving up. Real input invalidates an observation
/// rather than failing it, so this is what stops a source that keeps resetting
/// from retrying forever.
const int _maxAttempts = 20;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final sources = idleSources().where((s) => s.isSupported).toList();

  group('idle source', () {
    // This replaced a parity test that compared each binding against the
    // method-channel implementation. That implementation is gone, so there is
    // no second opinion left to check against — but this is still the only
    // place any FFI binding actually executes. The Dart job runs on Linux and
    // never opens user32.dll or IOKit, so without something here a wrong symbol
    // name or a wrong unit would ship.
    //
    // What survives the loss of the reference is a property the value has on
    // its own: while nobody touches the machine, the idle duration advances in
    // step with wall-clock time. In one respect that is a stronger check than
    // parity was — a binding returning nanoseconds or seconds instead of
    // milliseconds agrees with itself perfectly and fails this immediately.
    testWidgets(
      'advances in step with elapsed time while there is no input',
      (_) async {
        for (final source in sources) {
          var attempts = 0;
          while (true) {
            attempts++;
            expect(
              attempts,
              lessThanOrEqualTo(_maxAttempts),
              reason: '${source.name}: no observation ever showed the idle '
                  'clock advancing. Either input never stopped for long enough, '
                  'or the source is not reporting milliseconds — a source '
                  'returning seconds barely moves across this window and reads '
                  'small enough to be mistaken for a reset every time.',
            );

            // Two windows, because a read is not instantaneous and the growth
            // is measured between the instants the two reads *sampled*, which
            // is somewhere inside them. The IOKit walk in particular builds a
            // whole property dictionary and costs a few milliseconds.
            //
            // The outer window (start of the first read to end of the second)
            // is an upper bound on the sample gap; the inner one (the delay
            // alone, between the reads) is a lower bound. The true gap is
            // between them, so bounding the growth by both needs no constant
            // for how expensive a read happens to be.
            //
            // Windows never showed this: its 16 ms tick allowance was wide
            // enough to hide the read cost. macOS, reporting nanoseconds with a
            // 2 ms allowance, put it 5 ms outside.
            final outer = Stopwatch()..start();
            final before = source.idleMilliseconds();
            final inner = Stopwatch()..start();
            await Future<void>.delayed(_observation);
            inner.stop();
            final after = source.idleMilliseconds();
            outer.stop();

            final lowerBound = inner.elapsedMilliseconds - _clockGranularityMs;
            final upperBound = outer.elapsedMilliseconds + _clockGranularityMs;
            final growth = after - before;

            // Input during the window resets the clock, and the observation
            // then says nothing about the binding — discard it and take
            // another rather than failing.
            //
            // Checking the sign of the growth is not enough: input landing
            // *inside* the window leaves a small positive growth, not a
            // negative one (start at 99, reset, end at 100). What actually
            // marks a reset is coherence — a short growth is only explained by
            // one if the reading is now small enough to have started inside
            // this window. A short growth with a large reading has no such
            // explanation and is the binding being wrong, so it falls through
            // to the assertion.
            final shortGrowth = growth < lowerBound;
            final couldHaveResetInWindow = after <= upperBound;
            if (shortGrowth && couldHaveResetInWindow) continue;

            expect(before, greaterThanOrEqualTo(0));
            expect(
              growth,
              inInclusiveRange(lowerBound, upperBound),
              reason: '${source.name}: idle grew by ${growth}ms across a gap '
                  'that was between ${inner.elapsedMilliseconds}ms and '
                  '${outer.elapsedMilliseconds}ms. A binding reporting the '
                  'wrong unit lands far outside that; a stuck clock reads zero.',
            );
            break;
          }
        }
      },
      // Nothing to observe on a platform without a binding.
      skip: sources.isEmpty,
    );

    testWidgets('the demo screen shows a value per source', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IdleSourceDemo())),
      );
      await tester.pump(const Duration(milliseconds: 300));

      for (final source in idleSources()) {
        expect(
          find.text(source.name),
          findsOneWidget,
          reason: '${source.name} is missing from the screen',
        );
      }

      // A row has to show a number, not just a label — otherwise the screen
      // could render completely and still be useless.
      expect(
        find.textContaining(' ms'),
        findsNWidgets(sources.length),
        reason: 'every working source should be showing a value',
      );
    });

    testWidgets('records a reading in the log', (_) async {
      // A record for the CI log: a run that silently observed nothing looks
      // identical to a passing one.
      final readings = <String, int>{
        for (final source in sources) source.name: source.idleMilliseconds(),
      };
      debugPrint(
        'idle source on ${Platform.operatingSystem}: '
        '${sources.isEmpty ? 'none implemented' : readings}',
      );
    });
  });
}
