/// When the Notification fires, relative to the inactivity timeout.
///
/// A closed set: a trigger is *either* a percentage of the timeout
/// ([NotifyAtPercent]) *or* a fixed lead time before it ([NotifyBefore]) —
/// never both. Passing `null` where a trigger is expected means "no
/// Notification; fire only at timeout". See `CONTEXT.md`.
sealed class NotificationTrigger {
  const NotificationTrigger();
}

/// Fire the Notification once inactivity reaches [percent] of the timeout.
///
/// `NotifyAtPercent(80)` on a 60s timeout fires at 48s. [percent] must be in
/// the range 0–100.
class NotifyAtPercent extends NotificationTrigger {
  final int percent;
  const NotifyAtPercent(this.percent);
}

/// Fire the Notification [before] the timeout, independent of its length.
///
/// `NotifyBefore(Duration(seconds: 120))` on a 300s timeout fires at 180s.
/// [before] must be non-negative; a value `>=` the timeout is a
/// misconfiguration (asserted in debug) that safely resolves to firing
/// immediately when monitoring starts.
class NotifyBefore extends NotificationTrigger {
  final Duration before;
  const NotifyBefore(this.before);
}
