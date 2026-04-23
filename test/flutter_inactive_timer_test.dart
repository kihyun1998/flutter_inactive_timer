import 'package:fake_async/fake_async.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock platform whose "system tick" is synced with `FakeAsync.elapsed`, so
/// the production timer path sees time advance exactly as we elapse it.
class MockFlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  static const int baseTime = 100000;

  int Function() currentElapsedMs = () => 0;
  int lastInputElapsedMs = 0;

  @override
  Future<int> getSystemTickCount() async => baseTime + currentElapsedMs();

  @override
  Future<int> getLastInputTime() async => baseTime + lastInputElapsedMs;
}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform =
      FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });

  group('FlutterInactiveTimer', () {
    late MockFlutterInactiveTimerPlatform mock;

    setUp(() {
      mock = MockFlutterInactiveTimerPlatform();
      FlutterInactiveTimerPlatform.instance = mock;
    });

    test('init() creates an instance with zero defaults', () {
      final timer = FlutterInactiveTimer.init();
      expect(timer.timeoutDuration, 0);
      expect(timer.notificationPer, 0);
    });

    group('notification firing time', () {
      /// Drives a timer until `onInactiveDetected` fires (or the given cap
      /// elapses) and returns the ms offset at which `onNotification` first
      /// fired, or null if it never did.
      int? firstNotificationOffsetMs({
        required int timeoutDuration,
        required int notificationPer,
      }) {
        int? notifyAt;
        fakeAsync((async) {
          mock.currentElapsedMs = () => async.elapsed.inMilliseconds;

          final timer = FlutterInactiveTimer(
            timeoutDuration: timeoutDuration,
            notificationPer: notificationPer,
            onInactiveDetected: () {},
            onNotification: () {
              notifyAt ??= async.elapsed.inMilliseconds;
            },
          );

          timer.startMonitoring();
          async.flushMicrotasks();

          async.elapse(Duration(seconds: timeoutDuration));
          timer.stopMonitoring();
        });
        return notifyAt;
      }

      test('per=10, timeout=10s fires at 1000ms (10% elapsed)', () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 10, notificationPer: 10),
          1000,
        );
      });

      test('per=50, timeout=10s fires at 5000ms (50% elapsed)', () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 10, notificationPer: 50),
          5000,
        );
      });

      test('per=80, timeout=10s fires at 8000ms (80% elapsed)', () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 10, notificationPer: 80),
          8000,
        );
      });

      test('per=90, timeout=60s fires at 54000ms (regression: no busy-loop)',
          () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 60, notificationPer: 90),
          54000,
        );
      });

      test('per=0 never fires onNotification', () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 10, notificationPer: 0),
          isNull,
        );
      });

      test('per=10 does NOT fire at 90% (regression: inverted semantics)', () {
        // Before the fix this scenario fired at 9000ms because the scheduler
        // and the firing condition disagreed on what `per` meant.
        int? notifyAt;
        fakeAsync((async) {
          mock.currentElapsedMs = () => async.elapsed.inMilliseconds;

          final timer = FlutterInactiveTimer(
            timeoutDuration: 10,
            notificationPer: 10,
            onInactiveDetected: () {},
            onNotification: () {
              notifyAt ??= async.elapsed.inMilliseconds;
            },
          );

          timer.startMonitoring();
          async.flushMicrotasks();

          async.elapse(const Duration(milliseconds: 999));
          expect(notifyAt, isNull, reason: 'should not fire before 10% mark');

          async.elapse(const Duration(milliseconds: 2));
          expect(notifyAt, 1000, reason: 'must fire at the 10% mark');

          timer.stopMonitoring();
        });
      });
    });

    test('onInactiveDetected fires exactly at timeoutDuration', () {
      int? timeoutAt;

      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 5,
          notificationPer: 50,
          onInactiveDetected: () {
            timeoutAt ??= async.elapsed.inMilliseconds;
          },
          onNotification: () {},
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        timer.stopMonitoring();
      });

      expect(timeoutAt, 5000);
    });

    test('user activity reschedules the notification', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10, // target 1000ms of inactivity
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        // User moved at 500ms. When the check fires at 1000ms it should see
        // the newer input and reset _lastInputTime to 500ms, pushing the
        // notification target out to 500 + 1000 = 1500ms.
        async.elapse(const Duration(milliseconds: 500));
        mock.lastInputElapsedMs = 500;

        async.elapse(const Duration(milliseconds: 999));
        expect(notifyCount, 0,
            reason: 'notification must not fire at the old 1000ms target');

        async.elapse(const Duration(milliseconds: 10));
        expect(notifyCount, 1,
            reason: 'notification should fire once past the new 1500ms target');

        timer.stopMonitoring();
      });
    });

    test(
        'requireExplicitContinue blocks reset after notification until '
        'continueSession()', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int? timeoutAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          requireExplicitContinue: true,
          onInactiveDetected: () {
            timeoutAt ??= async.elapsed.inMilliseconds;
          },
          onNotification: () => notifyCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1, reason: 'notification fires at the 10% mark');

        // User activity AFTER notification — normally this resets, but with
        // requireExplicitContinue=true it should be ignored.
        mock.lastInputElapsedMs = 2000;
        async.elapse(const Duration(seconds: 9));

        expect(notifyCount, 1, reason: 'must not re-fire while locked');
        expect(timeoutAt, 10000, reason: 'must still reach timeout on time');
      });
    });

    test('continueSession() unlocks and restarts the cycle', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1);

        // Explicit continue at 2000ms → _lastInputTime resets, next notify at
        // 2000 + 1000 = 3000ms.
        async.elapse(const Duration(milliseconds: 999));
        timer.continueSession();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 999));
        expect(notifyCount, 1, reason: 'still before the new 1000ms window');

        async.elapse(const Duration(milliseconds: 10));
        expect(notifyCount, 2, reason: 'second notification after continue');

        timer.stopMonitoring();
      });
    });

    test('onActive fires when user returns after notification', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int activeCount = 0;
        int? activeAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          onActive: () {
            activeAt ??= async.elapsed.inMilliseconds;
            activeCount++;
          },
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1);
        expect(activeCount, 0,
            reason: 'onActive must not fire on notification');

        // User comes back at 1200ms. With 500ms polling, detection lands by
        // 1500ms at the latest.
        mock.lastInputElapsedMs = 1200;
        async.elapse(const Duration(milliseconds: 500));

        expect(activeCount, 1, reason: 'onActive must fire after user returns');
        expect(activeAt, lessThanOrEqualTo(1500),
            reason: 'polling must detect return within 500ms');

        timer.stopMonitoring();
      });
    });

    test('onActive does NOT fire when user moves before notification', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 50, // notify at 5s
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        // Reset before notification ever fires.
        async.elapse(const Duration(seconds: 2));
        mock.lastInputElapsedMs = 2000;
        async.elapse(const Duration(seconds: 4));

        expect(activeCount, 0, reason: 'no notification → no onActive');

        timer.stopMonitoring();
      });
    });

    test('onActive fires on continueSession() after notification', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(activeCount, 0);

        timer.continueSession();
        async.flushMicrotasks();

        expect(activeCount, 1);

        timer.stopMonitoring();
      });
    });

    test('onActive does NOT fire on continueSession() without notification',
        () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 50,
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 500));
        timer.continueSession();
        async.flushMicrotasks();

        expect(activeCount, 0,
            reason: 'no pending notification to recover from');

        timer.stopMonitoring();
      });
    });

    test('post-notification polling is capped at 500ms', () {
      // Regression test for the "reactivate latency" gap. With the old
      // max(remainTime, 1000) scheduler, user return at t=1.2s on a
      // timeout=10s / per=10 config would not be noticed until t=10s
      // (an 8.8s gap). The fix bounds it to 500ms.
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int? activeAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeAt ??= async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        mock.lastInputElapsedMs = 1200;

        async.elapse(const Duration(milliseconds: 499));
        expect(activeAt, isNotNull,
            reason: 'return at 1200ms must be seen within 500ms of next poll');
        expect(activeAt! - 1200, lessThanOrEqualTo(500));

        timer.stopMonitoring();
      });
    });

    test('stopMonitoring() prevents further callbacks', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int timeoutCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 10,
          notificationPer: 10,
          onInactiveDetected: () => timeoutCount++,
          onNotification: () => notifyCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 500));
        timer.stopMonitoring();

        async.elapse(const Duration(seconds: 30));

        expect(notifyCount, 0);
        expect(timeoutCount, 0);
      });
    });

    test('timeoutDuration=0 never schedules anything', () {
      fakeAsync((async) {
        mock.currentElapsedMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int timeoutCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: 0,
          notificationPer: 50,
          onInactiveDetected: () => timeoutCount++,
          onNotification: () => notifyCount++,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 60));

        expect(notifyCount, 0);
        expect(timeoutCount, 0);

        timer.stopMonitoring();
      });
    });
  });
}
