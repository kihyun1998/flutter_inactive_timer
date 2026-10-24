# Notification timing

## What it is
When the warning fires, relative to the timeout: the sealed `NotificationTrigger`
(`NotifyAtPercent` / `NotifyBefore`, or `null` for none) and the shell's
resolution of it to one millisecond offset, `notifyAtMs`, before anything reaches
the policy.

## Governing decisions
- [ADR-0002](../../adr/0002-notification-trigger-and-duration.md) — the sealed type, resolution in the shell, `Duration` everywhere, and the release-mode clamp.

## Design model
- **Never both kinds**: the type is `sealed`, so "percent and lead time both set" is unrepresentable (ADR-0002; `lib/src/notification_trigger.dart`).
- **Resolved once, in the shell**: `_resolveNotifyAtMs` runs in the constructor initializer; `NotifyAtPercent` → `timeoutMs * percent ~/ 100`, `NotifyBefore` → `(timeoutMs - before).clamp(0, timeoutMs)` (read in `_resolveNotifyAtMs`).
- **A new trigger kind is a new subclass plus a new `case` in `_resolveNotifyAtMs`**, and no change to the policy (ADR-0002, *Consequences*).
- **Validation is debug-only**: two constructor `assert`s bound `percent` to 0..100 and `before` to `[0, timeout)`. In release a too-long `NotifyBefore` clamps to fire at start (ADR-0002); see holes for `NotifyAtPercent`.

## Code
- `lib/src/notification_trigger.dart` — `NotificationTrigger`, `NotifyAtPercent`, `NotifyBefore`
- `lib/flutter_inactive_timer.dart` — `FlutterInactiveTimer` constructor asserts, `FlutterInactiveTimer._resolveNotifyAtMs`
- `test/flutter_inactive_timer_test.dart` — group `notification firing time`

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [inactivity-decision](inactivity-decision.md) — the policy assumes `notifyAtMs` is in `[0, timeoutMs]` and does not check it.
- [example-consumers](example-consumers.md) — both demos clamp `NotifyBefore` seconds to `1..timeout-1` themselves to honour the assert (`_SingleModeDemoState._buildTrigger`, `_MultiModeDemoState`); a changed rule leaves their clamps stale.
- [publishing](publishing.md) — the trigger is public API; a change is a CHANGELOG entry with a migration line (3.0.0 precedent).

## Known holes / open
- `NotifyAtPercent` above 100 in a release build resolves past the timeout, and the Notification silently never fires; below 0 it resolves negative and fires at start. ADR-0002 documents a release-mode answer only for `NotifyBefore`. Read in `_resolveNotifyAtMs` (no clamp on the percent arm).
