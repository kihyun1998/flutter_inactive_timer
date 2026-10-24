# Idle source resolution

## What it is
The `IdleSource` contract — one named, synchronous way of reading the idle
duration from the OS — and the pure function that picks the sources for an OS
name, including the `UnsupportedIdleSource` that explains, by throwing, that a
platform has no binding.

## Governing decisions
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md) — bindings read through `dart:ffi`; the CoreGraphics macOS candidate lost to IOKit.
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md) — a source returns an already-computed value, never two clocks.

## Design model
- **Resolution is a pure function of the OS name** (`idleSourcesFor(String)`), so the Windows and macOS arms are tested on the Linux CI host; only `idleSources()` / `defaultIdleSource()` read `Platform.operatingSystem` (read in `idle_sources.dart`; group `idleSourcesFor`).
- **A list, best-first, one entry per platform today**: the list shape survives from the period when macOS had two candidates (doc on `idleSourcesFor`; ADR-0004).
- **Sources are synchronous by contract** — no suspension point (doc on `IdleSource`).
- **Supported sources do not throw for OS failures; unsupported ones always throw** `UnsupportedError` naming the platform (`IdleSource.idleMilliseconds` doc, `UnsupportedIdleSource`). See [failed read reads as active](../invariant/failed-read-reads-as-active.md).
- `name` must identify the binding — it labels integration-test failures and the demo screen.

## Code
- `lib/src/ffi/idle_source.dart` — `IdleSource` (`name`, `isSupported`, `idleMilliseconds`), `UnsupportedIdleSource`
- `lib/src/ffi/idle_sources.dart` — `idleSourcesFor`, `defaultIdleSourceFor`, `idleSources`, `defaultIdleSource`
- `test/ffi_idle_source_test.dart` — groups `idleSourcesFor`, `unsupported platforms`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Failed read reads as active](../invariant/failed-read-reads-as-active.md) — the contract states it.
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — the contract's unit.

## Blast radius
- [windows-idle-binding](windows-idle-binding.md), [macos-idle-binding](macos-idle-binding.md) — each implements the contract; a contract change is two binding changes.
- [monitoring-lifecycle](monitoring-lifecycle.md) — what the unsupported source throws is what `_pump` swallows and retries forever.
- [on-device-verification](on-device-verification.md) — the integration test iterates `idleSources()` filtered by `isSupported`; a new source is tested there automatically, an unsupported one is skipped.

## Known holes / open
- Linux, web and mobile resolve to `UnsupportedIdleSource`; adding a platform is a new arm here plus a new binding territory. README *Roadmap* lists "additional platforms" with nothing committed.
