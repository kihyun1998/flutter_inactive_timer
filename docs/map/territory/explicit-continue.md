# Explicit continue

## What it is
The `requireExplicitContinue` mode: once the Notification has fired, user input
no longer resets the timer — only `continueSession()` does. Used where a warning
must be acknowledged, not merely survived by moving the mouse.

## Governing decisions
- [ADR-0003](../../adr/0003-remaining-time-pull-api.md) — names this mode as the reason an app cannot compute `timeout - idle` itself.

## Design model
- **The lock is set only by a Notification in this mode** (`_pump`, `FireNotification` arm: `if (requireExplicitContinue) _lockInputReset = true`) and **cleared only by a reset** (`_resetBaseline`), i.e. `startMonitoring` or `continueSession` — `ResetFromInput` cannot occur while locked.
- **While locked, inactivity is time since the reset, not idle** — see [effective inactivity](../invariant/effective-inactivity.md).
- **Locked waiting is coarse**: `_delay` floors the post-Notification wait at 1000 ms in this mode instead of polling at ≤500 ms, since input is ignored anyway (`_delay`).
- `continueSession` fires `onActive` only if a Notification was pending (`wasNotified`), and is a no-op when disposed, not monitoring, or timeout is zero.
- Status: from the glossary (*Explicit continue*) and source.

## Code
- `lib/flutter_inactive_timer.dart` — `FlutterInactiveTimer.requireExplicitContinue`, `continueSession`, `_lockInputReset` in `_pump` / `_resetBaseline` / `_snapshot`
- `lib/src/inactivity_policy.dart` — `InactivitySnapshot.isLocked`, the `!s.isLocked` test in `evaluate`, the locked arm of `_delay`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Effective inactivity](../invariant/effective-inactivity.md)

## Blast radius
- [inactivity-decision](inactivity-decision.md) — the lock flag gates the input-reset branch.
- [remaining-countdown](remaining-countdown.md) — the countdown must stop resetting on input exactly when the decision does.
- [example-consumers](example-consumers.md) — the Single-mode demo's snackbar "Continue Session" action is the only call to `continueSession` outside tests and the README (`_SingleModeDemoState._handleNotification`; `git grep -n 'continueSession()' -- '*.dart'`).

## Known holes / open
**None.**
