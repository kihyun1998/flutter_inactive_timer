import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:test/test.dart';

/// A platform whose idle read can be paused, so a test can hold one `_pump`
/// mid-`await` and race another operation against it.
class GatedIdlePlatform extends FlutterInactiveTimerPlatform {
  GatedIdlePlatform(this.nowMs);
  final int Function() nowMs;
  int lastInputMs = 0;
  Completer<void>? _hold; // armed by holdNextRead, before the read starts
  Completer<void>? _held; // the completer a parked read is awaiting

  /// Make the *next* idle read suspend until [releaseHeldRead].
  void holdNextRead() => _hold = Completer<void>();
  void releaseHeldRead() {
    // Complete whichever exists: the parked read's completer if the read has
    // already started, otherwise the not-yet-consumed armed one.
    (_held ?? _hold)?.complete();
    _hold = null;
    _held = null;
  }

  @override
  Future<int> getIdleDuration() async {
    final held = _hold;
    if (held != null) {
      _hold = null; // only this read is gated
      _held = held;
      await held.future;
      _held = null;
    }
    return nowMs() - lastInputMs;
  }
}

void main() {
  test(
      'continueSession racing an in-flight check leaves at most one timer and '
      'no duplicate notification', () {
    fakeAsync((async) {
      final gated = GatedIdlePlatform(() => async.elapsed.inMilliseconds);
      int notifyCount = 0;

      final timer = FlutterInactiveTimer(
        timeoutDuration: const Duration(seconds: 10),
        notification: const NotifyAtPercent(10), // notify at 1000ms
        onInactiveDetected: () {},
        onNotification: () => notifyCount++,
        platform: gated,
        clock: () => async.elapsed.inMilliseconds,
      );

      timer.startMonitoring();
      async.flushMicrotasks();
      expect(async.nonPeriodicTimerCount, 1);

      // Hold the notification check's idle read open, fire it, then race a
      // continueSession() against the parked check.
      gated.holdNextRead();
      async.elapse(const Duration(milliseconds: 1000));
      expect(notifyCount, 0, reason: 'parked check has not evaluated yet');

      timer.continueSession();
      async.flushMicrotasks();
      gated.releaseHeldRead();
      async.flushMicrotasks();

      expect(async.nonPeriodicTimerCount, lessThanOrEqualTo(1),
          reason: 'the overlap must not leave a ghost timer');

      // Run to completion; the notification must fire a sane number of times.
      async.elapse(const Duration(seconds: 20));
      expect(notifyCount, lessThanOrEqualTo(1),
          reason: 'the overlap must not double-fire the notification');

      timer.stopMonitoring();
    });
  });

  test('stop+start during an in-flight check does not leave a stale timer', () {
    fakeAsync((async) {
      final gated = GatedIdlePlatform(() => async.elapsed.inMilliseconds);
      int notifyCount = 0;

      final timer = FlutterInactiveTimer(
        timeoutDuration: const Duration(seconds: 10),
        notification: const NotifyAtPercent(10),
        onInactiveDetected: () {},
        onNotification: () => notifyCount++,
        platform: gated,
        clock: () => async.elapsed.inMilliseconds,
      );

      timer.startMonitoring();
      async.flushMicrotasks();

      // Park the check, then supersede its whole session with stop + start.
      gated.holdNextRead();
      async.elapse(const Duration(milliseconds: 1000));
      timer.stopMonitoring();
      timer.startMonitoring(); // fresh session, baseline at t=1000
      async.flushMicrotasks();
      gated.releaseHeldRead(); // superseded check resolves — must be a no-op
      async.flushMicrotasks();

      expect(async.nonPeriodicTimerCount, 1,
          reason: 'only the new session may hold a timer');

      // New session notifies once at 1000 + 1000 = 2000ms, not twice.
      async.elapse(const Duration(milliseconds: 1001));
      expect(notifyCount, 1);

      timer.stopMonitoring();
    });
  });

  test('dispose during an in-flight check arms no timer and fires no callback',
      () {
    fakeAsync((async) {
      final gated = GatedIdlePlatform(() => async.elapsed.inMilliseconds);
      int notifyCount = 0;
      int timeoutCount = 0;

      final timer = FlutterInactiveTimer(
        timeoutDuration: const Duration(seconds: 10),
        notification: const NotifyAtPercent(10),
        onInactiveDetected: () => timeoutCount++,
        onNotification: () => notifyCount++,
        platform: gated,
        clock: () => async.elapsed.inMilliseconds,
      );

      timer.startMonitoring();
      async.flushMicrotasks();

      gated.holdNextRead();
      async.elapse(const Duration(milliseconds: 1000));
      timer.dispose();
      gated.releaseHeldRead();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));

      expect(async.nonPeriodicTimerCount, 0,
          reason: 'a disposed timer must arm nothing');
      expect(notifyCount, 0);
      expect(timeoutCount, 0);
    });
  });

  test('remaining() racing stopMonitoring during its idle read returns zero',
      () {
    fakeAsync((async) {
      final gated = GatedIdlePlatform(() => async.elapsed.inMilliseconds);

      final timer = FlutterInactiveTimer(
        timeoutDuration: const Duration(seconds: 10),
        notification: const NotifyAtPercent(50),
        onInactiveDetected: () {},
        onNotification: () {},
        platform: gated,
        clock: () => async.elapsed.inMilliseconds,
      );

      timer.startMonitoring();
      async.flushMicrotasks(); // consumes the startup pump's (ungated) read

      // Park a remaining() call on a gated idle read...
      gated.holdNextRead();
      Duration? result;
      timer.remaining().then((d) => result = d);
      async.flushMicrotasks();

      // ...then supersede monitoring while the read is still in flight.
      timer.stopMonitoring();
      gated.releaseHeldRead();
      async.flushMicrotasks();

      // The post-await guard must win: no stale countdown after stop.
      expect(result, Duration.zero);
    });
  });
}
