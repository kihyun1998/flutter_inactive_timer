# Example consumers

## What it is
Two programs that use the package the way a consumer would: the Flutter example
app (single-timer demo, two independent timers, and the idle-source tab) and
`example_cli`, a plain `dart run` program with no Flutter anywhere. They prove
the public API is usable and that the pure-Dart claim stays true.

## Governing decisions
- [ADR-0005](../../adr/0005-pure-dart-package.md) — `example_cli/` exists to show the timer with no Flutter SDK in the resolution.
- [ADR-0003](../../adr/0003-remaining-time-pull-api.md) — the example demonstrates the caller-owned ticker.

## Design model
- **A new public API is proven by being used here** — `NotifyBefore` once shipped without appearing in the example (#10, [lessons](../../agents/lessons.md)).
- **`example_cli` is run by CI on both desktops** and exits on its own timeout, so a hang is a failure (ci.yml step `Dart CLI example`).
- **The Flutter demos dispose before replacing a timer** (`_SingleModeDemoState._setupInactivityTimer`, `_MultiModeDemoState._setupTimers`) and re-check `mounted` after every `await` (`_startTicker`, `_startMonitoring`).
- Both demos clamp `NotifyBefore` to `1..timeout-1` seconds before constructing.

## Code
- `example/lib/main.dart` — `TimerDemoTabs`, `SingleModeDemo` / `_SingleModeDemoState`, `MultiModeDemo` / `_MultiModeDemoState`
- `example/lib/idle_source_demo.dart` — `IdleSourceDemo` (shared with [on-device-verification](on-device-verification.md))
- `example_cli/bin/main.dart` — `main`
- `example/pubspec.yaml`, `example_cli/pubspec.yaml`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Resume-point recheck](../invariant/resume-point-recheck.md) — the demos' `mounted` checks are sites.

## Blast radius
- [publishing](publishing.md) — README snippets mirror these programs; a changed example usually means a changed README.
- [on-device-verification](on-device-verification.md) — the integration test lives in this app and pumps its widgets.

## Known holes / open
- `example_cli` ignores the result of `remaining()` resolving after `done` completes; harmless (it only writes to stdout) but unguarded.
