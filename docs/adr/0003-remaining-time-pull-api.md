# Remaining time is a pull API, not a stream

## Status

accepted

## Context and decision

Apps that show a live countdown ("logs out in 04:59") need the time left before
timeout at any moment. The existing callbacks (`onNotification`,
`onInactiveDetected`, `onActive`) fire at discrete points and don't provide a
continuously-queryable value. An app could compute `timeoutDuration - idle`
itself, but that is wrong under `requireExplicitContinue` lock: after the
Notification, input is ignored, so the true remaining time follows the reset
baseline, not the idle duration — and only the plugin knows the baseline and
lock state.

We decided to add a single method:

```dart
Future<Duration> remaining();
```

- **Pull, not push.** The plugin exposes a value to *query*; it does not own a
  ticker and does not emit a `Stream`/`ValueNotifier`. How often to repaint a
  countdown is a UI decision, and the plugin's identity is event-driven — it
  arms one timer and sleeps until the next decision point rather than waking
  every second (see the 1.2.0 busy-loop fix). Owning a per-second ticker for a
  display concern would contradict that.
- **Async.** A correct countdown must reset on fresh input, which requires the
  current idle duration, and `getIdleDuration()` is asynchronous. A synchronous
  getter could only read the (stale between polls) reset baseline, so before the
  Notification — when the plugin is asleep until the notify threshold — it would
  not reflect the user's activity at all.
- **The math is pure.** `InactivityPolicy.remainingMs(snapshot)` computes
  `timeout - effective` (effective = `sinceReset` when locked, else
  `min(idle, sinceReset)`), unit-tested without fakes. The shell's `remaining()`
  only does the idle read and the not-monitoring guard.
- **Not monitoring → `Duration.zero`.** A single rule covering before start,
  after stop/dispose, `timeoutDuration == Duration.zero`, and after the timeout
  has fired (the shell has stopped monitoring itself by then).

## Considered options

- **`Stream<Duration>` / `ValueNotifier<Duration>` (push).** Rejected: it makes
  the plugin own a ticker and a subscription lifecycle for what is a UI cadence,
  and a stream is trivially derivable from the getter
  (`Stream.periodic(...).map((_) => timer.remaining())`) when an app actually
  wants one. Root (getter) before leaf (stream); the leaf can be added
  non-breakingly later if real demand appears.
- **Both a getter and a stream.** Rejected: the stream's cost (plugin-owned
  ticker) is paid whether or not a getter also exists, for a value users can
  build themselves — the heaviest option for no unique capability.
- **Synchronous getter.** Rejected: cannot read fresh idle, so the countdown
  would not reset on activity before the Notification.

## Consequences

- Apps run their own `Timer.periodic` (or similar) and call `remaining()` each
  tick; the example demonstrates this in Single mode.
- Additive and non-breaking; shipped as part of the (still unreleased) 3.0.0.
- A future `remainingStream` can wrap the same pure `remainingMs` if push-style
  consumption is later warranted, with no change to `InactivityPolicy`.
