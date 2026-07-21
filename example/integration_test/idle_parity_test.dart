import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer_example/idle_parity_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Extra allowance on top of the measured read window: the coarsest step the
/// underlying clock takes on this platform, plus the rounding each binding does
/// on its way to whole milliseconds.
///
/// Elapsed time alone is not enough, because the clock the readers consult does
/// not advance smoothly. On Windows the system tick is **15.625 ms** by
/// default, and both `GetTickCount64` and the last-input time move only on that
/// tick — so two reads microseconds apart land on opposite sides of a tick
/// boundary and differ by a full step while almost no time has passed. That is
/// not disagreement between readers; it is the resolution of what they are
/// reading.
///
/// This is measured, not assumed: before the allowance existed this test failed
/// intermittently with spreads of exactly 15 ms and 16 ms — one tick — while
/// clean runs reported identical values. A real disagreement between bindings
/// would not cluster on the tick size.
///
/// Elsewhere the idle time is reported at a much finer resolution, so only the
/// millisecond rounding needs covering.
int get _clockGranularityMs => Platform.isWindows ? 16 : 2;

/// How many clean batches to require. One reading could be unlucky; a handful
/// makes a systematic offset between bindings visible while keeping the run
/// short.
const int _cleanBatchesWanted = 5;

/// How many batches to take at most before giving up. Batches spoiled by real
/// input are discarded rather than failed (see `_inputLandedMidBatch`), so this
/// is what stops a source that always reads low from retrying forever.
const int _maxBatches = 40;

/// Whether [readings], in the order they were taken, shows the idle clock
/// running *backwards* — which only happens when the user actually produced
/// input between two reads of the same batch.
///
/// This is the distinction that keeps the parity assertion honest. A later
/// reading that is too **large** means the readers disagree, which is the bug
/// this test exists to catch. A later reading that is **smaller** means the
/// world moved under the batch, and the batch says nothing about agreement — it
/// has to be discarded, not failed. Treating the second case as a failure makes
/// the test flake on any machine where something touches the input queue, which
/// includes the moment the app window is created.
bool _inputLandedMidBatch(List<int> readings) {
  for (var i = 1; i < readings.length; i++) {
    if (readings[i] < readings[i - 1] - _clockGranularityMs) return true;
  }
  return false;
}

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
        final discarded = <Map<String, int>>[];
        var clean = 0;
        var batches = 0;

        while (clean < _cleanBatchesWanted) {
          batches++;
          expect(
            batches,
            lessThanOrEqualTo(_maxBatches),
            reason: 'only got $clean of $_cleanBatchesWanted clean batches in '
                '$batches attempts. Every batch looked like it was interrupted '
                'by input, which is also what a source that always reads low '
                'looks like. Discarded batches: $discarded',
          );

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

          if (_inputLandedMidBatch(readings.values.toList(growable: false))) {
            discarded.add(readings);
            // Let the input settle rather than immediately re-reading into the
            // same burst — app startup in particular produces a cluster.
            await Future<void>.delayed(const Duration(milliseconds: 50));
            continue;
          }

          // Two components, and both are needed. The measured window covers how
          // much real time passed between the first read and the last; the
          // granularity covers the fact that the clock underneath them jumps in
          // steps rather than flowing. The first self-calibrates — a scheduling
          // hiccup that widens the window widens the allowance by exactly as
          // much — and the second is a property of the platform, not slop.
          final tolerance = stopwatch.elapsedMilliseconds + _clockGranularityMs;

          final spread = readings.values.reduce((a, b) => a > b ? a : b) -
              readings.values.reduce((a, b) => a < b ? a : b);

          expect(
            spread,
            lessThanOrEqualTo(tolerance),
            reason: 'batch $batches: readings disagree by ${spread}ms, more '
                'than the ${tolerance}ms this batch can account for — '
                '$readings. The idle clock did not run backwards here, so this '
                'is the readers disagreeing, not input landing mid-batch.',
          );
          clean++;
        }

        // A run that had to throw away most of its batches passed, but only
        // just, and the next one may not. Say so rather than reporting a bare
        // green.
        debugPrint(
          'idle parity: $clean clean batches from $batches attempts '
          '(${discarded.length} discarded to mid-batch input)',
        );
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

      // A source that works must show a number, not just its label. Without
      // this the screen could render every row and still be useless, which is
      // the failure mode it was built to rule out.
      expect(
        find.textContaining(' ms'),
        findsNWidgets(1 + implemented.length), // the channel, plus each source
        reason: 'every working reader should be showing a value',
      );

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

    testWidgets('records a sample batch in the log', (_) async {
      // Not an assertion — a record in the CI log. A parity run that silently
      // compared nothing looks identical to a passing one, and the ticket that
      // has to choose between the two macOS bindings needs the actual numbers
      // from a machine nobody here owns. Printing them is the only way they
      // reach a human.
      if (implemented.isEmpty) {
        debugPrint(
          'idle parity on ${Platform.operatingSystem}: '
          'no FFI source implemented yet',
        );
        return;
      }

      final channel = MethodChannelFlutterInactiveTimer();
      final stopwatch = Stopwatch()..start();
      final readings = <String, int>{
        'method channel': await channel.getIdleDuration(),
        for (final source in implemented)
          source.name: source.idleMilliseconds(),
      };
      stopwatch.stop();

      debugPrint(
        'idle parity on ${Platform.operatingSystem}: '
        'batch took ${stopwatch.elapsedMilliseconds}ms, readings $readings',
      );
    });
  });
}
