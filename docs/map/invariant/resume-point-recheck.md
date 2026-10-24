# Resume-point recheck

## The fact
Any code that `await`s an idle read (or anything that awaits one) must, at the
resume point, re-read every piece of state it relies on — `_generation`,
`_isMonitoring`, `mounted` — before acting. A `stop` / `start` / `continue` /
`dispose` can land while it is suspended.

## Why it is cross-cutting
The hazard is the async seam ([platform-seam](../territory/platform-seam.md)),
but each site guards its own state with its own check: the shell's step, the
countdown, and every widget that awaits the timer. None of them calls another,
and no shared helper does the re-check, so fixing one leaves the others as they
were. The same-shaped bug happened four times, each at a different site
([lessons](../../agents/lessons.md)).

## Territories it holds in
- [platform-seam](../territory/platform-seam.md) — not a site but the source: `FlutterInactiveTimerPlatform.getIdleDuration` returns a `Future`, so every caller has a resume point.
- [monitoring-lifecycle](../territory/monitoring-lifecycle.md) — `FlutterInactiveTimer._pump`: `if (gen != _generation || !_isMonitoring) return;`, and the same test in its `catch`.
- [remaining-countdown](../territory/remaining-countdown.md) — `FlutterInactiveTimer.remaining`: `if (!_isMonitoring) return Duration.zero;` after the read.
- [example-consumers](../territory/example-consumers.md) — `_SingleModeDemoState._startTicker` and `_startMonitoring`: `if (mounted)` / `if (!mounted) return;` after the await.

## What a violation looks like
A callback firing after `stopMonitoring` / `dispose`, a second live timer (a
"ghost" that fires twice), a non-zero `remaining()` after stop, or a
`setState` after the widget is gone. Reproduces only when the stop lands while
the read is parked — `GatedIdlePlatform` (`test/ghost_timer_test.dart`) parks it
on demand.

## Discovery history
- `07ac425` — `_checkInactivity` did not re-check `isMonitoring` after await ([lessons](../../agents/lessons.md)).
- `9759514` — the example used `BuildContext` after an await.
- `8c03f6f` (#5) — a stale schedule armed a timer after await; sealed with the generation counter.
- `a6abd0f` (#17) — `remaining()` raced `stopMonitoring` mid-read.

## Where it will recur
If a function awaits `getIdleDuration()`, `remaining()`, `startMonitoring()` or
any future async read, and then touches timer state or UI, it is subject to
this. `git grep -n "await" -- lib example example_cli` lists the candidates.
The FFI read is synchronous underneath, so the window is narrow today — but the
seam is still async, and a custom platform can suspend for as long as it likes.
