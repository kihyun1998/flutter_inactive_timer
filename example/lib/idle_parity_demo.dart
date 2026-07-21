import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';

/// One row of the parity table: what a single reader reported this tick.
class _Reading {
  const _Reading.value(this.name, this.milliseconds) : error = null;
  const _Reading.failure(this.name, this.error) : milliseconds = null;

  final String name;
  final int? milliseconds;
  final String? error;
}

/// Shows the Idle duration as reported by the method channel next to every FFI
/// source available on this platform, refreshed continuously.
///
/// This is the eyeball half of the same check the parity integration test
/// automates. Its job is to make a disagreement between bindings visible while
/// you move the mouse and stop moving it — the moment of truth for "the FFI
/// rewrite behaves identically" is watching all columns fall to zero together
/// on input and climb together afterwards.
class IdleParityDemo extends StatefulWidget {
  const IdleParityDemo({super.key});

  @override
  State<IdleParityDemo> createState() => _IdleParityDemoState();
}

class _IdleParityDemoState extends State<IdleParityDemo> {
  final MethodChannelFlutterInactiveTimer _channel =
      MethodChannelFlutterInactiveTimer();
  late final List<IdleSource> _sources = idleSources();

  Timer? _ticker;
  List<_Reading> _readings = const [];
  int? _spreadMs;

  /// Guards against a tick starting while the previous one is still parked on
  /// the channel read. Two overlapping batches would finish out of order and
  /// paint an older reading over a newer one — and worse, mix values sampled at
  /// different moments into one spread, which is the number this screen exists
  /// to report.
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _read());
    _read();
  }

  Future<void> _read() async {
    if (_reading) return;
    _reading = true;

    // `finally` rather than a flag reset at each exit: the early return below
    // and any throw would otherwise wedge the guard permanently on and freeze
    // the screen.
    try {
      final readings = <_Reading>[];

      try {
        readings.add(
          _Reading.value('method channel', await _channel.getIdleDuration()),
        );
      } catch (e) {
        readings.add(_Reading.failure('method channel', '$e'));
      }

      // The widget can be torn down while the channel read above is in flight —
      // the same resume-point hazard that has bitten this package four times
      // (docs/agents/lessons.md). Re-check before touching state.
      if (!mounted) return;

      for (final source in _sources) {
        try {
          readings.add(_Reading.value(source.name, source.idleMilliseconds()));
        } catch (e) {
          // Expected until that platform's binding lands: the source throws
          // with a message naming itself, which is what we want on screen.
          readings.add(_Reading.failure(source.name, '$e'));
        }
      }

      final values = readings
          .map((r) => r.milliseconds)
          .whereType<int>()
          .toList(growable: false);

      setState(() {
        _readings = readings;
        _spreadMs = values.length < 2
            ? null
            : values.reduce((a, b) => a > b ? a : b) -
                values.reduce((a, b) => a < b ? a : b);
      });
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spread = _spreadMs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Idle duration by reader',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stop touching the keyboard and mouse and every value should climb '
            'together; move the mouse and they should all drop to about zero at '
            'once. A column that drifts on its own is the bug this screen '
            'exists to catch.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final reading in _readings) ...[
                    _ReadingRow(reading: reading),
                    if (reading != _readings.last) const Divider(height: 16),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                spread == null
                    ? 'Only one reader is producing values, so there is nothing '
                        'to compare yet. The FFI bindings land one platform at '
                        'a time.'
                    : 'Spread between readers: ${spread}ms — this is the number '
                        'the parity test bounds by how long a batch of reads '
                        'took, plus a small rounding allowance.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});

  final _Reading reading;

  @override
  Widget build(BuildContext context) {
    final error = reading.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            reading.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: error != null
              ? Text(
                  error,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : Text(
                  '${reading.milliseconds} ms',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ],
    );
  }
}
