import 'package:fake_async/fake_async.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake platform whose idle duration is derived from a test-controlled clock:
/// `idle = now - lastInput`. Set [nowMs] to `FakeAsync.elapsed` and move
/// [lastInputMs] forward to simulate the user producing input at that time.
class FakeIdlePlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  int Function() nowMs = () => 0;
  int lastInputMs = 0;

  @override
  Future<int> getIdleDuration() async => nowMs() - lastInputMs;
}

/// Fake platform that throws on the next [throwsRemaining] idle reads, to
/// exercise the shell's transient-failure recovery path.
class FlakyIdlePlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  FlakyIdlePlatform(this.nowMs);
  final int Function() nowMs;
  int lastInputMs = 0;
  int throwsRemaining = 0;

  @override
  Future<int> getIdleDuration() async {
    if (throwsRemaining > 0) {
      throwsRemaining--;
      throw Exception('transient platform failure');
    }
    return nowMs() - lastInputMs;
  }
}

/// A platform that overrides nothing, so it inherits the base's
/// not-implemented behavior.
class UnimplementedPlatform extends FlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin {}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform =
      FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });

  test(
      'platform interface getIdleDuration throws until a platform implements it',
      () {
    expect(UnimplementedPlatform().getIdleDuration, throwsUnimplementedError);
  });

  group('FlutterInactiveTimer', () {
    late FakeIdlePlatform mock;

    setUp(() {
      mock = FakeIdlePlatform();
      FlutterInactiveTimerPlatform.instance = mock;
    });

    test('init() creates an instance with zero defaults', () {
      final timer = FlutterInactiveTimer.init();
      expect(timer.timeoutDuration, Duration.zero);
      expect(timer.notification, isNull);
    });

    test('NotifyBefore >= timeout asserts (no valid firing point)', () {
      expect(
        () => FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyBefore(Duration(seconds: 15)),
          onInactiveDetected: () {},
          onNotification: () {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('NotifyBefore with a negative lead time asserts', () {
      expect(
        () => FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyBefore(Duration(seconds: -1)),
          onInactiveDetected: () {},
          onNotification: () {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    group('notification firing time', () {
      /// Drives a timer until `onInactiveDetected` fires (or the given cap
      /// elapses) and returns the ms offset at which `onNotification` first
      /// fired, or null if it never did.
      int? firstNotificationOffsetMs({
        required int timeoutDuration,
        required NotificationTrigger? notification,
      }) {
        int? notifyAt;
        fakeAsync((async) {
          mock.nowMs = () => async.elapsed.inMilliseconds;

          final timer = FlutterInactiveTimer(
            timeoutDuration: Duration(seconds: timeoutDuration),
            notification: notification,
            onInactiveDetected: () {},
            onNotification: () {
              notifyAt ??= async.elapsed.inMilliseconds;
            },
            platform: mock,
            clock: () => async.elapsed.inMilliseconds,
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
          firstNotificationOffsetMs(
              timeoutDuration: 10, notification: const NotifyAtPercent(10)),
          1000,
        );
      });

      test('per=50, timeout=10s fires at 5000ms (50% elapsed)', () {
        expect(
          firstNotificationOffsetMs(
              timeoutDuration: 10, notification: const NotifyAtPercent(50)),
          5000,
        );
      });

      test('per=80, timeout=10s fires at 8000ms (80% elapsed)', () {
        expect(
          firstNotificationOffsetMs(
              timeoutDuration: 10, notification: const NotifyAtPercent(80)),
          8000,
        );
      });

      test('per=90, timeout=60s fires at 54000ms (regression: no busy-loop)',
          () {
        expect(
          firstNotificationOffsetMs(
              timeoutDuration: 60, notification: const NotifyAtPercent(90)),
          54000,
        );
      });

      test('null notification never fires onNotification', () {
        expect(
          firstNotificationOffsetMs(timeoutDuration: 10, notification: null),
          isNull,
        );
      });

      test('NotifyBefore(3s), timeout=10s fires at 7000ms (3s before timeout)',
          () {
        expect(
          firstNotificationOffsetMs(
            timeoutDuration: 10,
            notification: const NotifyBefore(Duration(seconds: 3)),
          ),
          7000,
        );
      });

      test('NotifyBefore(0) never fires: it coincides with timeout', () {
        // notifyAt == timeout, and the policy checks timeout before the
        // notification, so the timeout preempts it. No notification is emitted.
        expect(
          firstNotificationOffsetMs(
            timeoutDuration: 10,
            notification: const NotifyBefore(Duration.zero),
          ),
          isNull,
        );
      });

      test('per=10 does NOT fire at 90% (regression: inverted semantics)', () {
        int? notifyAt;
        fakeAsync((async) {
          mock.nowMs = () => async.elapsed.inMilliseconds;

          final timer = FlutterInactiveTimer(
            timeoutDuration: const Duration(seconds: 10),
            notification: const NotifyAtPercent(10),
            onInactiveDetected: () {},
            onNotification: () {
              notifyAt ??= async.elapsed.inMilliseconds;
            },
            platform: mock,
            clock: () => async.elapsed.inMilliseconds,
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
        mock.nowMs = () => async.elapsed.inMilliseconds;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 5),
          notification: const NotifyAtPercent(50),
          onInactiveDetected: () {
            timeoutAt ??= async.elapsed.inMilliseconds;
          },
          onNotification: () {},
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
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
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10), // target 1000ms of inactivity
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        // User moved at 500ms. When the check fires at 1000ms it should see the
        // newer input (idle < sinceReset) and rewind the baseline to 500ms,
        // pushing the notification target out to 500 + 1000 = 1500ms.
        async.elapse(const Duration(milliseconds: 500));
        mock.lastInputMs = 500;

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
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int? timeoutAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          requireExplicitContinue: true,
          onInactiveDetected: () {
            timeoutAt ??= async.elapsed.inMilliseconds;
          },
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1, reason: 'notification fires at the 10% mark');

        // User activity AFTER notification — normally this resets, but with
        // requireExplicitContinue=true it should be ignored.
        mock.lastInputMs = 2000;
        async.elapse(const Duration(seconds: 9));

        expect(notifyCount, 1, reason: 'must not re-fire while locked');
        expect(timeoutAt, 10000, reason: 'must still reach timeout on time');
      });
    });

    test('continueSession() unlocks and restarts the cycle', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1);

        // Explicit continue at 2000ms → baseline resets, next notify at
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
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int activeCount = 0;
        int? activeAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          onActive: () {
            activeAt ??= async.elapsed.inMilliseconds;
            activeCount++;
          },
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        expect(notifyCount, 1);
        expect(activeCount, 0,
            reason: 'onActive must not fire on notification');

        // User comes back at 1200ms. With 500ms polling, detection lands by
        // 1500ms at the latest.
        mock.lastInputMs = 1200;
        async.elapse(const Duration(milliseconds: 500));

        expect(activeCount, 1, reason: 'onActive must fire after user returns');
        expect(activeAt, lessThanOrEqualTo(1500),
            reason: 'polling must detect return within 500ms');

        timer.stopMonitoring();
      });
    });

    test('onActive does NOT fire when user moves before notification', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(50), // notify at 5s
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        // Reset before notification ever fires.
        async.elapse(const Duration(seconds: 2));
        mock.lastInputMs = 2000;
        async.elapse(const Duration(seconds: 4));

        expect(activeCount, 0, reason: 'no notification → no onActive');

        timer.stopMonitoring();
      });
    });

    test('onActive fires on continueSession() after notification', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
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
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int activeCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(50),
          requireExplicitContinue: true,
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
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
      // Regression test for the "reactivate latency" gap. The fix bounds the
      // detection of the user's return to 500ms.
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int? activeAt;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () {},
          onNotification: () {},
          onActive: () => activeAt ??= async.elapsed.inMilliseconds,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1001));
        mock.lastInputMs = 1200;

        async.elapse(const Duration(milliseconds: 499));
        expect(activeAt, isNotNull,
            reason: 'return at 1200ms must be seen within 500ms of next poll');
        expect(activeAt! - 1200, lessThanOrEqualTo(500));

        timer.stopMonitoring();
      });
    });

    test('stopMonitoring() prevents further callbacks', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int timeoutCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () => timeoutCount++,
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
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

    test('a transient platform failure does not kill monitoring; it retries',
        () {
      fakeAsync((async) {
        final platform = FlakyIdlePlatform(() => async.elapsed.inMilliseconds);
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          platform: platform,
          clock: () => async.elapsed.inMilliseconds,
        );

        // The first idle read (from startMonitoring) throws. Monitoring must
        // survive and re-arm a retry rather than silently dying.
        platform.throwsRemaining = 1;
        timer.startMonitoring();
        async.flushMicrotasks();
        expect(async.nonPeriodicTimerCount, 1,
            reason: 'a failed check must re-arm, not abandon monitoring');

        // Subsequent reads succeed; normal scheduling resumes and the
        // notification still fires exactly once.
        async.elapse(const Duration(seconds: 12));
        expect(notifyCount, 1,
            reason: 'monitoring recovered and reached the notification');

        timer.stopMonitoring();
      });
    });

    test('dispose() cancels the timer and prevents further callbacks', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int timeoutCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () => timeoutCount++,
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 500));
        timer.dispose();

        async.elapse(const Duration(seconds: 30));

        expect(notifyCount, 0);
        expect(timeoutCount, 0);
      });
    });

    test('startMonitoring() after dispose() is a no-op', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () {},
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.dispose();
        timer.startMonitoring();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));

        expect(notifyCount, 0,
            reason: 'a disposed timer must not resume monitoring');
      });
    });

    test('dispose() is idempotent', () {
      final timer = FlutterInactiveTimer.init();
      expect(timer.dispose, returnsNormally);
      expect(timer.dispose, returnsNormally);
    });

    test('timeoutDuration=0 never schedules anything', () {
      fakeAsync((async) {
        mock.nowMs = () => async.elapsed.inMilliseconds;
        int notifyCount = 0;
        int timeoutCount = 0;

        final timer = FlutterInactiveTimer(
          timeoutDuration: Duration.zero,
          notification: const NotifyAtPercent(50),
          onInactiveDetected: () => timeoutCount++,
          onNotification: () => notifyCount++,
          platform: mock,
          clock: () => async.elapsed.inMilliseconds,
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

  // Issue #1: the timer must be usable with a platform injected through the
  // constructor, WITHOUT mutating the global FlutterInactiveTimerPlatform
  // singleton. This group deliberately never assigns
  // FlutterInactiveTimerPlatform.instance (except the precedence test, which
  // restores it).
  group('constructor platform injection', () {
    test('uses the injected platform (no global singleton mutation)', () {
      int? notifyAt;
      fakeAsync((async) {
        final injected = FakeIdlePlatform()
          ..nowMs = () => async.elapsed.inMilliseconds;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10), // notify at 10% -> 1000ms
          onInactiveDetected: () {},
          onNotification: () => notifyAt ??= async.elapsed.inMilliseconds,
          platform: injected,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        timer.stopMonitoring();
      });

      expect(notifyAt, 1000);
    });

    test('injected platform takes precedence over the global singleton', () {
      final original = FlutterInactiveTimerPlatform.instance;
      addTearDown(() => FlutterInactiveTimerPlatform.instance = original);

      // Frozen global: idle is always 0. If the timer ever read the global
      // instead of the injected platform, idle (0) < sinceReset would trigger a
      // perpetual reset and the notification would never fire.
      final frozenGlobal = FakeIdlePlatform()..nowMs = () => 0;
      FlutterInactiveTimerPlatform.instance = frozenGlobal;

      int? notifyAt;
      fakeAsync((async) {
        final injected = FakeIdlePlatform()
          ..nowMs = () => async.elapsed.inMilliseconds;

        final timer = FlutterInactiveTimer(
          timeoutDuration: const Duration(seconds: 10),
          notification: const NotifyAtPercent(10),
          onInactiveDetected: () {},
          onNotification: () => notifyAt ??= async.elapsed.inMilliseconds,
          platform: injected,
          clock: () => async.elapsed.inMilliseconds,
        );

        timer.startMonitoring();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        timer.stopMonitoring();
      });

      // Fires per the injected (advancing) idle — the frozen global was never
      // consulted.
      expect(notifyAt, 1000);
    });
  });
}
