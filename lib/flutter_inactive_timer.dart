import 'dart:async';

import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_inactive_timer/src/inactivity_policy.dart';

class FlutterInactiveTimer {
  /// The duration of inactivity before timeout (in seconds)
  final int timeoutDuration;

  /// Percentage of timeout duration when notification should trigger (0-100)
  /// If set to 0, no notification will be triggered
  final int notificationPer;

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

  /// Creates an inactive timer with required parameters.
  ///
  /// [platform] defaults to [FlutterInactiveTimerPlatform.instance] and [clock]
  /// to a monotonic [Stopwatch]; supply fakes in tests to avoid touching global
  /// state and to drive time deterministically.
  FlutterInactiveTimer({
    required this.timeoutDuration,
    required this.notificationPer,
    required this.onInactiveDetected,
    required this.onNotification,
    this.onActive,
    this.requireExplicitContinue = false, // default behavior
    FlutterInactiveTimerPlatform? platform,
    int Function()? clock,
    InactivityPolicy policy = const InactivityPolicy(),
  })  : _platform = platform ?? FlutterInactiveTimerPlatform.instance,
        _now = clock ?? _defaultClock(),
        _policy = policy;

  /// Initialize with default values (no monitoring)
  factory FlutterInactiveTimer.init() => FlutterInactiveTimer(
        notificationPer: 0,
        timeoutDuration: 0,
        onInactiveDetected: () {},
        onNotification: () {},
      );

  static int Function() _defaultClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMilliseconds;
  }

  /// Called when the user explicitly chooses to continue the session
  void continueSession() {
    if (_disposed || !_isMonitoring || timeoutDuration == 0) return;
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

    if (timeoutDuration != 0) {
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
        timeoutMs: timeoutDuration * 1000,
        notificationPer: notificationPer,
        requireExplicitContinue: requireExplicitContinue,
        isNotified: _isNotification,
        isLocked: _lockInputReset,
      );

  /// One monitoring step: read the idle duration, ask the policy what to do,
  /// execute the decision, and schedule the next step.
  Future<void> _pump() async {
    if (!_isMonitoring || timeoutDuration == 0) return;
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
