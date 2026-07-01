import 'dart:math';

/// Immutable snapshot of everything [InactivityPolicy] needs to make a
/// decision. All times are in milliseconds.
class InactivitySnapshot {
  /// Milliseconds since the user's last real input (from the platform).
  final int idleMs;

  /// Monotonic milliseconds since the last logical reset (start / continue /
  /// detected input), measured by the shell's clock.
  final int sinceResetMs;

  /// Timeout in milliseconds (`timeoutDuration * 1000`). Never zero — the shell
  /// does not schedule checks when the timeout is disabled.
  final int timeoutMs;

  /// Percentage of the timeout at which the notification fires (0 disables it).
  final int notificationPer;

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
    required this.notificationPer,
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

    if (s.notificationPer > 0 && !s.isNotified) {
      final reachedPer = effective * 100 ~/ s.timeoutMs;
      if (reachedPer >= s.notificationPer) {
        return FireNotification(
          delayMs: _delay(s, effective: effective, notified: true),
        );
      }
    }

    return ScheduleNext(delayMs: _delay(s, effective: effective));
  }

  /// Milliseconds to wait before the next check, given [effective] inactivity
  /// and the notification state (overridable for decisions that change it).
  int _delay(InactivitySnapshot s, {required int effective, bool? notified}) {
    final isNotified = notified ?? s.isNotified;
    final remain = s.timeoutMs - effective;
    if (s.notificationPer == 0) return remain > 0 ? remain : 1;

    final notifyTime = (s.timeoutMs * s.notificationPer / 100).round();
    if (remain <= 0) return 1;
    if (effective < notifyTime) {
      return isNotified ? remain : notifyTime - effective;
    }
    if (!isNotified) return 1;
    return s.requireExplicitContinue ? max(remain, 1000) : min(remain, 500);
  }
}
