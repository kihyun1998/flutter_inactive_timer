# Notification timing is a NotificationTrigger, resolved to a single offset

## Status

accepted

## Context and decision

The Notification could originally only be scheduled as `notificationPer` — an
integer percentage of the timeout — and `notificationPer: 0` doubled as the
"no Notification" switch. Callers also wanted to schedule the Notification a
**fixed lead time before** the timeout (e.g. "120 seconds before"), which is
independent of the timeout's length and cannot be expressed as a percentage
without recomputing it whenever the timeout changes.

We decided:

- **Timing is a sealed `NotificationTrigger`** — either `NotifyAtPercent(int)`
  or `NotifyBefore(Duration)`. Exactly one kind applies; the two can never be
  set at once because they are the same value. "No Notification" is `null`, not
  a magic `0`.
- **The shell resolves the trigger to one absolute offset.**
  `FlutterInactiveTimer` computes `notifyAtMs` (ms since reset, or `null`) once
  from the trigger and the timeout, and passes only that number into
  `InactivityPolicy`. The policy never sees the trigger kind.
- **All durations are `Duration`.** `timeoutDuration` moves from `int` seconds
  to `Duration`, so the whole public API speaks one unambiguous time type.

## Considered options

- **Add a `notificationBefore` field alongside `notificationPer`, plus a `mode`
  flag.** Rejected: it makes the illegal "both set / mode disagrees with the
  populated field" state representable, forcing runtime validation for
  something the type system can enforce.
- **Pass the trigger object into `InactivityPolicy` and `switch` there.**
  Rejected: the policy would have to change every time a new trigger kind is
  added. Resolving to `notifyAtMs` in the shell keeps the policy closed to that
  change — it only ever compares `effective >= notifyAtMs`.
- **Keep `notificationPer` (deprecated) beside the new API for one release.**
  Rejected: two coexisting ways to set the timing reintroduces the "both set"
  ambiguity at the constructor, undermining the sealed design. A clean break
  with a one-line migration was preferred, consistent with this package's
  history of deliberate, documented breaking changes (see ADR-0001).

## Consequences

- Breaking change, shipped as a major version bump (3.0.0). Callers migrate
  `notificationPer: 50` → `notification: NotifyAtPercent(50)` and
  `timeoutDuration: 60` → `timeoutDuration: Duration(seconds: 60)`.
- `NotifyBefore.before` must be `>= 0` and `<` the timeout; both are asserted in
  debug. A lead time `>=` the timeout has no firing point inside the window, so
  in release it clamps to fire immediately at monitoring start rather than
  crashing.
- When the resolved offset equals the timeout (`NotifyBefore(Duration.zero)` or
  `NotifyAtPercent(100)`), the timeout preempts the Notification — the policy
  checks the timeout before the Notification — so no Notification fires. This
  needs no special-casing.
- A future timing kind (e.g. "at a fixed wall-clock time") is added as a new
  `NotificationTrigger` subclass and a new branch in the shell's resolver, with
  no change to `InactivityPolicy`.
