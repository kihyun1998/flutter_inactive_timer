// A minimal command-line demo of flutter_inactive_timer, with no Flutter
// involved at any point — not in this program, and not transitively.
//
// Run it, then stop touching the keyboard and mouse:
//
//   dart run
//
// The countdown ticks down; the moment you press a key or move the mouse it
// jumps back to the full timeout. Leave it alone long enough and the timeout
// fires and the program exits.
//
// Since 4.0.0 this package is pure Dart (ADR-0005), which is what makes a
// program like this possible. Before that, the same code needed a Flutter
// engine to carry the idle duration across a method channel — for a number the
// operating system will hand to any process that asks.

import 'dart:async';
import 'dart:io';

import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';

const _timeout = Duration(seconds: 15);

Future<void> main() async {
  stdout.writeln('Watching for inactivity. Timeout: ${_timeout.inSeconds}s.');
  stdout.writeln('Keep still to watch it count down; type to reset it.\n');

  final done = Completer<void>();
  late final FlutterInactiveTimer timer;

  timer = FlutterInactiveTimer(
    timeoutDuration: _timeout,
    // Warn with a fixed lead time rather than a percentage, so the warning is
    // in the same place however the timeout above is edited.
    notification: NotifyBefore(const Duration(seconds: 5)),
    onNotification: () => stdout.writeln('\n  ! 5 seconds left'),
    onActive: () => stdout.writeln('\n  ~ welcome back'),
    onInactiveDetected: () {
      stdout.writeln('\n  x inactive — session would end here');
      done.complete();
    },
  );

  await timer.startMonitoring();

  // remaining() is a pull API: the package owns no ticker, so the cadence of
  // the display is this program's business (ADR-0003). One second here.
  final ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
    final left = await timer.remaining();
    stdout.write('\r  ${left.inSeconds.toString().padLeft(2)}s remaining  ');
  });

  await done.future;
  ticker.cancel();
  timer.dispose();
}
