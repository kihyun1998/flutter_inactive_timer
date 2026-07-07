import 'dart:async';

import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_inactive_timer/src/inactivity_policy.dart';
import 'package:flutter_inactive_timer/src/notification_trigger.dart';

export 'package:flutter_inactive_timer/src/notification_trigger.dart';

class FlutterInactiveTimer {
  /// The duration of inactivity before timeout.
  final Duration timeoutDuration;

  /// When the notification fires, relative to the timeout — either a
  /// percentage of it ([NotifyAtPercent]) or a fixed lead time before it
  /// ([NotifyBefore]). `null` means no notification: only the timeout fires.
  final NotificationTrigger? notification;

  /// Callback that is called when inactivity timeout is reached
  final void Function() onInactiveDetected;

  /// Callback that is called when notification threshold is reached
  final void Function() onNotification;

  /// Callback that is called when the user becomes active again after a
  /// notification has fired. Invoked both on detected input (when
  /// `requireExplicitContinue` is false) and on [continueSession] calls.
  /// Optional — existing callers can omit it.
  final void Function()? onActive;

  /// If true, only explicit continue action will reset the timer after notification
  /// If false, any user activity will reset the timer (default behavior)
  final bool requireExplicitContinue;

  /// The platform used to read the idle duration. Injected via the constructor
  /// so callers (and tests) can supply their own, decoupling this timer from
  /// the global [FlutterInactiveTimerPlatform.instance].
  final FlutterInactiveTimerPlatform _platform;

  /// Monotonic clock (milliseconds). Injected so tests can drive it with a
  /// virtual clock; production uses a [Stopwatch]. See ADR-0001 — the idle
  /// duration comes from the platform, but wall-clock progress since a reset
  /// (needed while input is locked out) comes from this clock.
  final int Function() _now;

  final InactivityPolicy _policy;

  /// Absolute inactivity offset (ms) at which the notification fires, or `null`
  /// for no notification. Resolved once from [notification] and
  /// [timeoutDuration] so the policy stays agnostic to the trigger kind.
  final int? _notifyAtMs;

  /// The value of [_now] at the last logical reset (start / continue / detected
  /// input). "Inactivity since our reset" is `_now() - _baselineNow`.
  int _baselineNow = 0;

  Timer? _timer;
  bool _isNotification = false;
  bool _isMonitoring = false;
  bool _lockInputReset = false;
  bool _disposed = false;

  /// Bumped whenever the current schedule is invalidated (start / stop /
  /// continue / dispose). A `_pump` that was already in flight across its
  /// `await` when the generation changed aborts instead of arming a stale
  /// timer, guaranteeing at most one live timer even under overlapping calls.
  int _generation = 0;

  /// Creates an inactive timer.
  ///
  /// [notification] defaults to `null` — no Notification, only the timeout
  /// fires. Supply [NotifyAtPercent] or [NotifyBefore] to warn before it.
  ///
  /// [platform] defaults to [FlutterInactiveTimerPlatform.instance] and [clock]
  /// to a monotonic [Stopwatch]; supply fakes in tests to avoid touching global
  /// state and to drive time deterministically.
  FlutterInactiveTimer({
    required this.timeoutDuration,
    this.notification,
    required this.onInactiveDetected,
    required this.onNotification,
    this.onActive,
    this.requireExplicitContinue = false, // default behavior
    FlutterInactiveTimerPlatform? platform,
    int Function()? clock,
    InactivityPolicy policy = const InactivityPolicy(),
  })  : assert(
          notification is! NotifyAtPercent ||
              (notification.percent >= 0 && notification.percent <= 100),
          'NotifyAtPercent.percent must be in the range 0..100',
        ),
        assert(
          notification is! NotifyBefore ||
              (notification.before >= Duration.zero &&
                  notification.before < timeoutDuration),
          'NotifyBefore.before must be >= 0 and shorter than timeoutDuration',
        ),
        _platform = platform ?? FlutterInactiveTimerPlatform.instance,
        _now = clock ?? _defaultClock(),
        _policy = policy,
        _notifyAtMs =
            _resolveNotifyAtMs(notification, timeoutDuration.inMilliseconds);

  /// Initialize with default values (no monitoring)
  factory FlutterInactiveTimer.init() => FlutterInactiveTimer(
        notification: null,
        timeoutDuration: Duration.zero,
        onInactiveDetected: () {},
        onNotification: () {},
      );

  /// Resolves a [NotificationTrigger] to the absolute inactivity offset (ms) at
  /// which the notification should fire, or `null` for no notification.
  static int? _resolveNotifyAtMs(NotificationTrigger? trigger, int timeoutMs) {
    switch (trigger) {
      case null:
        return null;
      case NotifyAtPercent(:final percent):
        return timeoutMs * percent ~/ 100;
      case NotifyBefore(:final before):
        // A lead time >= the timeout has no valid firing point inside the
        // window; clamp so it fires immediately when monitoring starts.
        return (timeoutMs - before.inMilliseconds).clamp(0, timeoutMs);
    }
  }

  static int Function() _defaultClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMilliseconds;
  }

  /// The time left before [onInactiveDetected] fires, for driving a live
  /// countdown in the UI.
  ///
  /// Reads the current idle duration, so the countdown resets on user activity
  /// (except in [requireExplicitContinue] lock, where input is ignored — see
  /// [InactivityPolicy.remainingMs]). Returns [Duration.zero] when not
  /// monitoring: before [startMonitoring], after [stopMonitoring] / [dispose],
  /// when [timeoutDuration] is zero, or once the timeout has already fired.
  ///
  /// This is a *pull* API — call it from your own periodic ticker (e.g. a
  /// one-second `Timer.periodic`) to repaint; the timer keeps no ticker of its
  /// own.
  Future<Duration> remaining() async {
    if (!_isMonitoring || timeoutDuration == Duration.zero) {
      return Duration.zero;
    }
    final int idleMs = await _platform.getIdleDuration();
    if (!_isMonitoring) return Duration.zero;
    return Duration(milliseconds: _policy.remainingMs(_snapshot(idleMs)));
  }

  /// Called when the user explicitly chooses to continue the session
  void continueSession() {
    if (_disposed || !_isMonitoring || timeoutDuration == Duration.zero) return;
    _generation++;
    final wasNotified = _isNotification;
    _resetBaseline(_now());
    if (wasNotified) onActive?.call();
    _pump();
  }

  /// Start monitoring for user inactivity
  Future<void> startMonitoring() async {
    if (_disposed) return;
    _generation++;
    _isMonitoring = true;
    _resetBaseline(_now());

    if (timeoutDuration != Duration.zero) {
      await _pump();
    }
  }

  /// Stop monitoring for user inactivity.
  ///
  /// This is a *pause*: monitoring can be resumed later with
  /// [startMonitoring]. To permanently tear the timer down, use [dispose].
  void stopMonitoring() {
    _isMonitoring = false;
    _generation++;
    _timer?.cancel();
  }

  /// Permanently tear down this timer: cancel the active timer and release its
  /// hold on this instance so it (and its callbacks) can be garbage collected.
  ///
  /// Unlike [stopMonitoring] (a pause), a disposed timer cannot be restarted —
  /// [startMonitoring] and [continueSession] become no-ops. Safe to call more
  /// than once. Call this from your widget's `State.dispose`.
  void dispose() {
    _disposed = true;
    _isMonitoring = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  /// Reset the baseline and clear notification/lock state.
  void _resetBaseline(int baselineNow) {
    _baselineNow = baselineNow;
    _isNotification = false;
    _lockInputReset = false;
  }

  void _arm(int delayMs) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delayMs), _pump);
  }

  InactivitySnapshot _snapshot(int idleMs) => InactivitySnapshot(
        idleMs: idleMs,
        sinceResetMs: _now() - _baselineNow,
        timeoutMs: timeoutDuration.inMilliseconds,
        notifyAtMs: _notifyAtMs,
        requireExplicitContinue: requireExplicitContinue,
        isNotified: _isNotification,
        isLocked: _lockInputReset,
      );

  /// One monitoring step: read the idle duration, ask the policy what to do,
  /// execute the decision, and schedule the next step.
  Future<void> _pump() async {
    if (!_isMonitoring || timeoutDuration == Duration.zero) return;
    final int gen = _generation;

    try {
      final int idleMs = await _platform.getIdleDuration();
      // A stop / start / continue / dispose happened while we were awaiting:
      // this check belongs to a superseded schedule, so drop it rather than
      // arm a stale timer.
      if (gen != _generation || !_isMonitoring) return;

      final decision = _policy.evaluate(_snapshot(idleMs));
      switch (decision) {
        case ResetFromInput(:final delayMs, :final fireOnActive):
          // Rewind the baseline to the real input moment so the countdown
          // resumes from when the user actually acted, not when we noticed.
          _resetBaseline(_now() - idleMs);
          if (fireOnActive) onActive?.call();
          _arm(delayMs);
        case FireNotification(:final delayMs):
          _isNotification = true;
          if (requireExplicitContinue) _lockInputReset = true;
          onNotification();
          _arm(delayMs);
        case FireInactive():
          onInactiveDetected();
          stopMonitoring();
        case ScheduleNext(:final delayMs):
          _arm(delayMs);
      }
    } catch (_) {
      // A transient platform failure shouldn't kill monitoring; try again —
      // unless this check was superseded while awaiting.
      if (gen == _generation && _isMonitoring) _arm(1000);
    }
  }
}
