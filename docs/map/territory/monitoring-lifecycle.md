# Monitoring lifecycle

## What it is
The imperative shell: `FlutterInactiveTimer` owns time, the timer, the platform
read and the instance's state (monitoring, notified, locked, disposed). It runs
one step at a time — read the idle duration, ask the policy, carry out the
decision, arm the next step — and exposes `startMonitoring` / `stopMonitoring` /
`continueSession` / `dispose`.

## Governing decisions
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md) — the shell receives one idle value; it measures only its own reset baseline.
- [ADR-0003](../../adr/0003-remaining-time-pull-api.md) — the shell owns no ticker; it arms one timer per decision point.

## Design model
- **At most one live timer.** `_arm` cancels before reassigning, and `_generation` is bumped by every start / stop / continue / dispose; a `_pump` that resumes from its `await` under a different generation returns without arming (`_pump`). Origin: #5, commit `8c03f6f` ([lessons](../../agents/lessons.md)).
- **`stopMonitoring` is a pause, `dispose` is permanent**: `_disposed` makes `startMonitoring` and `continueSession` no-ops (read in both).
- **Timeout ends monitoring**: `FireInactive` calls `onInactiveDetected` then `stopMonitoring()` (`_pump`).
- **A throwing read is a transient fault**: `_pump` catches everything and re-arms after 1000 ms, unless superseded. This is why sources must not throw for ordinary OS failures ([failed read reads as active](../invariant/failed-read-reads-as-active.md)).
- `timeoutDuration == Duration.zero` disables scheduling entirely (`startMonitoring`, `_pump`, `continueSession` guards); `FlutterInactiveTimer.init()` builds that inert instance.
- Clock and platform are constructor-injected (`clock`, `platform`); the default clock is a `Stopwatch` (`_defaultClock`).
- Status: the generation rule comes from the incident record (#5); the rest only from source.

## Code
- `lib/flutter_inactive_timer.dart` — `FlutterInactiveTimer` (constructor, `init`, `startMonitoring`, `stopMonitoring`, `continueSession`, `dispose`, `_resetBaseline`, `_arm`, `_snapshot`, `_pump`, `_defaultClock`)
- `test/flutter_inactive_timer_test.dart` — wiring tests through `FakeIdlePlatform` and `fake_async`
- `test/ghost_timer_test.dart` — `GatedIdlePlatform` parks a read mid-`await` to reproduce races

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Resume-point recheck](../invariant/resume-point-recheck.md) — `_pump`'s generation check is a site.
- [Failed read reads as active](../invariant/failed-read-reads-as-active.md) — `_pump`'s catch-and-retry is why the rule exists.
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — `_defaultClock` is the shell's half of the scale.

## Blast radius
- [inactivity-decision](inactivity-decision.md) — the snapshot's fields are the policy's only input; a field computed differently here changes every decision.
- [remaining-countdown](remaining-countdown.md) — `remaining()` reads the same `_isMonitoring` / baseline state and has its own resume point.
- [explicit-continue](explicit-continue.md) — `_lockInputReset` is set here and cleared only by `_resetBaseline`.
- [platform-seam](platform-seam.md) — the shell assumes `getIdleDuration` may suspend; a seam change that adds or removes suspension changes which races exist.

## Known holes / open
- On an OS with no binding, `UnsupportedIdleSource.idleMilliseconds` throws `UnsupportedError`, `_pump` catches it as transient and re-arms every 1000 ms indefinitely, with no callback and no error surfaced. Whether that is intended is undecided (maintainer, 2026-10-24: "don't know").
- `_defaultClock` is a `Stopwatch`, which keeps running across system sleep on some hosts and not others; how a sleep/wake cycle reads to the baseline was not checked.
