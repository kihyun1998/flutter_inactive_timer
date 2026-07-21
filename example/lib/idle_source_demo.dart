import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';

/// One reading: what a source reported this tick.
class _Reading {
  const _Reading.value(this.name, this.milliseconds) : error = null;
  const _Reading.failure(this.name, this.error) : milliseconds = null;

  final String name;
  final int? milliseconds;
  final String? error;
}

/// Shows the Idle duration as reported by this platform's [IdleSource],
/// refreshed continuously.
///
/// This screen began as a side-by-side comparison against the method-channel
/// implementation — that is how the FFI bindings were shown to report the same
/// values before the native code was deleted (ADR-0004). With nothing left to
/// compare against, what it demonstrates now is the raw quantity the whole
/// package is built on: watch it climb while you keep still, and drop to zero
/// the moment you touch the keyboard or mouse.
class IdleSourceDemo extends StatefulWidget {
  const IdleSourceDemo({super.key});

  @override
  State<IdleSourceDemo> createState() => _IdleSourceDemoState();
}

class _IdleSourceDemoState extends State<IdleSourceDemo> {
  late final List<IdleSource> _sources = idleSources();

  Timer? _ticker;
  List<_Reading> _readings = const [];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _read());
    _read();
  }

  /// Reads every source once.
  ///
  /// Synchronous throughout. The method-channel version of this screen needed a
  /// re-entrancy guard and a `mounted` re-check because its read suspended at an
  /// `await`; an FFI read is a plain function call, so neither hazard exists
  /// here. That simplification is the same one that removed a whole family of
  /// bugs from the timer itself (`docs/agents/lessons.md`).
  void _read() {
    final readings = <_Reading>[];

    for (final source in _sources) {
      try {
        readings.add(_Reading.value(source.name, source.idleMilliseconds()));
      } catch (e) {
        // Reached on a platform with no binding, where the source throws with a
        // message naming itself — which is exactly what we want on screen.
        readings.add(_Reading.failure(source.name, '$e'));
      }
    }

    setState(() => _readings = readings);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Idle duration, straight from the OS',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Milliseconds since your last keyboard or mouse input, read through '
            'dart:ffi. Keep still and it climbs; touch anything and it drops to '
            'about zero. Every countdown in this package is derived from this '
            'one number.',
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
