import 'dart:math';

/// Immutable snapshot of everything [InactivityPolicy] needs to make a
/// decision. All times are in milliseconds.
class InactivitySnapshot {
  /// Milliseconds since the user's last real input (from the platform).
  final int idleMs;

  /// Monotonic milliseconds since the last logical reset (start / continue /
  /// detected input), measured by the shell's clock.
  final int sinceResetMs;

  /// Timeout in milliseconds. Never zero — the shell does not schedule checks
  /// when the timeout is disabled.
  final int timeoutMs;

  /// Absolute inactivity offset (ms since reset) at which the Notification
  /// fires, or `null` for no Notification. The shell resolves the caller's
  /// `NotificationTrigger` to this single value, so the policy never needs to
  /// know whether it came from a percentage or a fixed lead time.
  final int? notifyAtMs;

  final bool requireExplicitContinue;

  /// Whether the notification has already fired this cycle.
  final bool isNotified;

  /// Whether input resets are locked out (only set after a notification when
  /// [requireExplicitContinue] is true).
  final bool isLocked;

  const InactivitySnapshot({
    required this.idleMs,
    required this.sinceResetMs,
    required this.timeoutMs,
    required this.notifyAtMs,
    required this.requireExplicitContinue,
    required this.isNotified,
    required this.isLocked,
  });
}

/// The closed set of outcomes [InactivityPolicy.evaluate] can return.
sealed class InactivityDecision {
  const InactivityDecision();
}

/// Nothing to fire; arm the next check after [delayMs].
class ScheduleNext extends InactivityDecision {
  final int delayMs;
  const ScheduleNext({required this.delayMs});
}

/// The notification threshold was crossed for the first time this cycle.
class FireNotification extends InactivityDecision {
  final int delayMs;
  const FireNotification({required this.delayMs});
}

/// The timeout was reached — stop monitoring.
class FireInactive extends InactivityDecision {
  const FireInactive();
}

/// User activity was detected since the last reset — reset the baseline to the
/// real input moment and, if a notification had fired, fire onActive.
class ResetFromInput extends InactivityDecision {
  final int delayMs;
  final bool fireOnActive;
  const ResetFromInput({required this.delayMs, required this.fireOnActive});
}

/// Pure decision rule for inactivity monitoring. Owns no timer and makes no
/// platform calls — given an [InactivitySnapshot] it returns an
/// [InactivityDecision]. See `CONTEXT.md`.
class InactivityPolicy {
  const InactivityPolicy();

  /// The inactivity time left before timeout, in milliseconds, for the given
  /// snapshot. Unlocked, the user's fresh input counts (so the countdown resets
  /// on activity); locked, input is ignored and only the reset baseline counts.
  /// Clamped to `[0, timeoutMs]`.
  int remainingMs(InactivitySnapshot s) {
    final effective =
        s.isLocked ? s.sinceResetMs : min(s.idleMs, s.sinceResetMs);
    return (s.timeoutMs - effective).clamp(0, s.timeoutMs);
  }

  InactivityDecision evaluate(InactivitySnapshot s) {
    // The user's last input is more recent than our reset baseline: they were
    // active since we last reset. Ignored while locked (requireExplicitContinue
    // after a notification).
    if (!s.isLocked && s.idleMs < s.sinceResetMs) {
      return ResetFromInput(
        delayMs: _delay(s, effective: s.idleMs, notified: false),
        fireOnActive: s.isNotified,
      );
    }

    final effective = s.sinceResetMs;

    if (effective >= s.timeoutMs) {
      return const FireInactive();
    }

    final notifyAt = s.notifyAtMs;
    if (notifyAt != null && !s.isNotified && effective >= notifyAt) {
      return FireNotification(
        delayMs: _delay(s, effective: effective, notified: true),
      );
    }

    return ScheduleNext(delayMs: _delay(s, effective: effective));
  }

  /// Milliseconds to wait before the next check, given [effective] inactivity
  /// and the notification state (overridable for decisions that change it).
  int _delay(InactivitySnapshot s, {required int effective, bool? notified}) {
    final isNotified = notified ?? s.isNotified;
    final remain = s.timeoutMs - effective;
    final notifyAt = s.notifyAtMs;
    if (notifyAt == null) return remain > 0 ? remain : 1;

    if (remain <= 0) return 1;
    if (effective < notifyAt) {
      return isNotified ? remain : notifyAt - effective;
    }
    if (!isNotified) return 1;
    return s.requireExplicitContinue ? max(remain, 1000) : min(remain, 500);
  }
}
