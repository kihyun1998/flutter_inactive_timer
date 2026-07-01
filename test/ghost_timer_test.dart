import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform whose idle read can be paused, so a test can hold one `_pump`
/// mid-`await` and race another operation against it.
class GatedIdlePlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  GatedIdlePlatform(this.nowMs);
  final int Function() nowMs;
  int lastInputMs = 0;
  Completer<void>? _hold;

  /// Make the *next* idle read suspend until [releaseHeldRead].
  void holdNextRead() => _hold = Completer<void>();
  void releaseHeldRead() {
    _hold?.complete();
    _hold = null;
  }

  @override
  Future<int> getIdleDuration() async {
    final held = _hold;
    if (held != null) {
      _hold = null; // only this read is gated
      await held.future;
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
        timeoutDuration: 10,
        notificationPer: 10, // notify at 1000ms
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
        timeoutDuration: 10,
        notificationPer: 10,
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
        timeoutDuration: 10,
        notificationPer: 10,
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
}
