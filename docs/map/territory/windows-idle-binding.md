# Windows idle binding

## What it is
`WindowsIdleSource`: reads the idle duration on Windows by calling
`GetLastInputInfo` (user32) and `GetTickCount64` (kernel32) through `dart:ffi`
and subtracting them in the 32-bit domain the last-input tick lives in.

## Governing decisions
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md) — the 32-bit `dwTime` wrap (~49.7 days) that motivated returning one value.
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md) — the FFI port must reproduce the retired C++ exactly.

## Design model
- **Wrap-safe subtraction**: `(tickCount64 - lastInputTick) & 0xFFFFFFFF` — truncate the 64-bit tick to 32 bits and subtract modulo 2^32 (`idleFromTicks`; tests in group `WindowsIdleSource.idleFromTicks`).
- **Decisions in a pure static, plumbing under `coverage:ignore`**: `idleFromTicks` holds the arithmetic and the failure rule and is tested on Linux; `idleMilliseconds` and the lazily-resolved `_getLastInputInfo` / `_getTickCount64` hold none. Lazy top-level `final`s are what keep the file importable on Linux (comment above them).
- `cbSize` must be set to the struct size before the call or the API fails (`_LastInputInfo` doc). The struct is `calloc`'d and freed on every call, since this runs on every poll.
- Behaviour-identical to the retired C++ by rule: "any difference here is a regression by definition" (class doc; ADR-0004).

## Code
- `lib/src/ffi/windows_idle_source.dart` — `_LastInputInfo`, `_getLastInputInfo`, `_getTickCount64`, `WindowsIdleSource.idleFromTicks`, `WindowsIdleSource.idleMilliseconds`
- `test/windows_idle_source_test.dart`

## Reference behaviour
- Win32 `GetLastInputInfo` / `LASTINPUTINFO` — binding, reached through summarized docs ([thegraph.md](../../agents/thegraph.md)): settles `cbSize`, `dwTime` width and tick units.

## Cross-cutting invariants
- [Failed read reads as active](../invariant/failed-read-reads-as-active.md) — `idleFromTicks(succeeded: false)` returns 0.
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — ticks are already milliseconds.

## Blast radius
- [on-device-verification](on-device-verification.md) — the only place `user32.dll` is opened; a wrong symbol, signature or unit passes every Linux gate. Its tolerance assumes this binding's 15.625 ms tick.
- [dart-ci-gates](dart-ci-gates.md) — moving logic out of `idleFromTicks` into the ignored region shrinks the coverage denominator and hides it (`--check-ignore`).

## Known holes / open
- Wrap safety holds only for spans shorter than one 2^32 ms lap; a real idle span cannot reach that, so this is noted, not open.
