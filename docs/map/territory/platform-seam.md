# Platform seam

## What it is
The boundary between the timer and whatever reads the idle duration:
`FlutterInactiveTimerPlatform` (one method, `getIdleDuration`), its global
default `instance`, and `FfiFlutterInactiveTimer`, the adapter that wraps an
`IdleSource` in the async contract. Tests and unsupported platforms plug in here.

## Governing decisions
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md) — the seam carries one idle duration in ms.
- [ADR-0003](../../adr/0003-remaining-time-pull-api.md) — why the method is `Future<int>`.
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md) — the default is the FFI adapter.
- [ADR-0005](../../adr/0005-pure-dart-package.md) — a plain abstract class; the extend-don't-implement rule kept without its runtime token.

## Design model
- **Extend, never implement**: `getIdleDuration` has a default body (throws `UnimplementedError`) so an `extends` subclass survives the interface growing; an `implements` one breaks at compile time (ADR-0005; read in the class).
- **`instance` is a plain mutable static** defaulting to `FfiFlutterInactiveTimer()`; the per-instance `platform:` constructor parameter is preferred (doc on `instance`).
- **Async on the outside, sync underneath**: `FfiFlutterInactiveTimer.getIdleDuration` is `async` only to fit the seam; `IdleSource.idleMilliseconds` is synchronous (read in both).
- The adapter exposes its `source` so a harness can label which binding produced a value.

## Code
- `lib/flutter_inactive_timer_platform_interface.dart` — `FlutterInactiveTimerPlatform`, `FlutterInactiveTimerPlatform.instance`, `getIdleDuration`
- `lib/flutter_inactive_timer_ffi.dart` — `FfiFlutterInactiveTimer`, re-exports of the `src/ffi/` library
- `test/ffi_idle_source_test.dart` — group `FfiFlutterInactiveTimer`
- `test/flutter_inactive_timer_test.dart` — group `constructor platform injection`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Resume-point recheck](../invariant/resume-point-recheck.md) — whether a read suspends is decided here.

## Blast radius
- [monitoring-lifecycle](monitoring-lifecycle.md) — the shell's generation guard exists because the seam is async; the FFI adapter's own doc says a new suspension point is where that guard must be revisited.
- [remaining-countdown](remaining-countdown.md) — the async signature of `remaining()` follows from this method's.
- [publishing](publishing.md) — the class is public; README's "Migrating to 4.0.0" shows custom-platform authors the `extends` form.
- [idle-source-resolution](idle-source-resolution.md) — the adapter's default source comes from `defaultIdleSource()`.

## Known holes / open
- `FfiFlutterInactiveTimer`'s doc comment still says "**Not the default yet** … `instance` still resolves to the method-channel implementation", which has been false since `411ea57` made FFI the default. Left as is (map does not edit source); listed in the hub's findings.
