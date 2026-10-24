# Remaining countdown

## What it is
`remaining()`: the time left before `onInactiveDetected`, queried on demand so an
app can paint "logs out in 04:59". A pull API — the package owns no ticker.

## Governing decisions
- [ADR-0003](../../adr/0003-remaining-time-pull-api.md) — pull not push, async, pure math, `Duration.zero` when not monitoring.
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md), [ADR-0005](../../adr/0005-pure-dart-package.md) — both record that a synchronous `remaining()` is now possible and both decline to take it.

## Design model
- **Shell does the read and the guard; policy does the math**: `remaining()` returns zero if not monitoring or timeout is zero, awaits the idle read, re-checks `_isMonitoring`, then returns `InactivityPolicy.remainingMs(_snapshot(idleMs))` (read in both).
- `remainingMs` clamps to `[0, timeoutMs]`.
- **Not monitoring → zero** covers before start, after stop/dispose, zero timeout, and after the timeout fired (ADR-0003; `FireInactive` stops monitoring).
- Callers drive the cadence: the README, the Flutter example and `example_cli` each run their own `Timer.periodic`.

## Code
- `lib/flutter_inactive_timer.dart` — `FlutterInactiveTimer.remaining`
- `lib/src/inactivity_policy.dart` — `InactivityPolicy.remainingMs`
- `test/ghost_timer_test.dart` — `remaining() racing stopMonitoring during its idle read returns zero`
- `test/inactivity_policy_test.dart` — the three `remainingMs` tests

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Effective inactivity](../invariant/effective-inactivity.md) — `remainingMs` is a site.
- [Resume-point recheck](../invariant/resume-point-recheck.md) — the post-`await` `_isMonitoring` check is a site.

## Blast radius
- [inactivity-decision](inactivity-decision.md) — the countdown and the decision must reach zero at the same instant.
- [example-consumers](example-consumers.md) — the Flutter demo re-checks `mounted` after awaiting `remaining()` (`_SingleModeDemoState._startTicker`); a synchronous signature would remove that resume point, and `example_cli` and the README snippet would need the same edit.
- [publishing](publishing.md) — making it synchronous is a breaking public-signature change.

## Known holes / open
- Synchronous `remaining()`: possible since the FFI read, deferred twice, not decided (ADR-0004, ADR-0005).
- It does not check `generation`, only `_isMonitoring`: a `stop` + `start` landing during its read returns a value computed against the new baseline. Read in `remaining`; whether that is wrong was not settled.
