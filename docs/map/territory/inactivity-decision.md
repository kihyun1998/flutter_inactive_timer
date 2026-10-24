# Inactivity decision

## What it is
The pure rule that turns one reading — idle duration, time since the last reset,
config, whether a Notification already fired, whether input is locked — into
exactly one `InactivityDecision`: reset from input, fire the Notification, fire
Inactive, or schedule the next check and say when. It owns no timer and makes no
platform call; the shell executes what it returns
([monitoring-lifecycle](monitoring-lifecycle.md)).

## Governing decisions
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md) — the policy is designed around one idle duration, not timestamps.
- [ADR-0002](../../adr/0002-notification-trigger-and-duration.md) — the policy sees only `notifyAtMs`, never the trigger kind, and checks the timeout before the Notification.

## Design model
- **Decision order is fixed** (`InactivityPolicy.evaluate`): input-reset first, then timeout, then Notification, else schedule. Checking the timeout before the Notification is what makes `NotifyAtPercent(100)` / `NotifyBefore(Duration.zero)` fire no Notification without a special case (ADR-0002, *Consequences*; read in `evaluate`).
- **Input is detected by comparison, not by event**: `idleMs < sinceResetMs` means input landed after the last reset (`evaluate`). The shell then rewinds the baseline to the input moment (`_pump`, `ResetFromInput` arm: `_resetBaseline(_now() - idleMs)`).
- **The rule sleeps until the next decision point** rather than polling (`_delay`): before the Notification it waits exactly until `notifyAtMs`; after it, unlocked polling is capped at 500 ms (to catch the user's return) and locked waiting is floored at 1000 ms. Read in `_delay`; tests `unlocked post-notification polling is capped at 500ms`, `locked post-notification wait is floored at 1000ms` (`test/inactivity_policy_test.dart`). The event-driven shape is ADR-0003's stated identity ("arms one timer and sleeps until the next decision point").
- `onActive` fires only on a reset that follows a Notification: `ResetFromInput.fireOnActive = s.isNotified` (`evaluate`).
- Status: the order and the closed outcome set come from the ADRs; the delay constants (500/1000/1) only from source.

## Code
- `lib/src/inactivity_policy.dart` — `InactivitySnapshot`, `InactivityDecision` (`ScheduleNext`, `FireNotification`, `FireInactive`, `ResetFromInput`), `InactivityPolicy.evaluate`, `InactivityPolicy._delay`
- `test/inactivity_policy_test.dart` — pure decision tests, no fakes

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Effective inactivity](../invariant/effective-inactivity.md) — `evaluate`'s lock test is one of its two sites.
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — `idleMs` is compared directly with the shell clock's `sinceResetMs`.

## Blast radius
- [monitoring-lifecycle](monitoring-lifecycle.md) — the shell's `switch` over `InactivityDecision` must cover every outcome; a new decision kind is a compile error there only because the class is `sealed`.
- [explicit-continue](explicit-continue.md) — the lock flag changes both which branch is taken and the post-Notification delay.
- [remaining-countdown](remaining-countdown.md) — `remainingMs` must agree with `evaluate` on what "inactive for X ms" means.
- [notification-timing](notification-timing.md) — the policy trusts `notifyAtMs` to be already resolved and in range; it does no validation of its own.

## Known holes / open
- `notifyAtMs > timeoutMs` is not guarded here: the timeout always wins, so the Notification silently never fires. Reachable only through [notification-timing](notification-timing.md)'s release-mode hole.
