# macOS idle binding

## What it is
`MacOsIoKitIdleSource`: reads the idle duration on macOS by walking the IO
registry to the `IOHIDSystem` service and unboxing its `HIDIdleTime` property
(nanoseconds) through `dart:ffi`, against IOKit and CoreFoundation.

## Governing decisions
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md) — FFI over the method channel; IOKit chosen over the CoreGraphics candidate, which measured ~9 ms off (CHANGELOG 4.0.0, *Why this is safe*).

## Design model
- **Truncating ns → ms, negatives clamped to 0** — matches the retired Swift's integer division; rounding would be a behaviour change (`idleFromNanoseconds` doc; group `MacOsIoKitIdleSource.idleFromNanoseconds`).
- **Ownership traps in the walk**: the matching dictionary is consumed by `IOServiceGetMatchingServices` on success *and* failure (never released here); the `CFDictionaryGetValue` result is borrowed (never released). Everything else — iterator, entry, property dictionary, key string — is released on every path (doc on `_readIdleNanoseconds`).
- **Mach handles are 32-bit ints, not pointers** — typing them as pointers compiles and corrupts the stack (comment at the top of the file).
- **The default IO port is the literal 0** rather than a looked-up symbol, because `kIOMasterPortDefault` was renamed `kIOMainPortDefault` in macOS 12 (`_defaultIoPort` doc).
- Same split as Windows: pure static `idleFromNanoseconds` tested on Linux; the walk under `coverage:ignore`.

## Code
- `lib/src/ffi/macos_iokit_idle_source.dart` — `MacOsIoKitIdleSource.idleFromNanoseconds`, `idleMilliseconds`, `_readIdleNanoseconds`, `_readIdleNanosecondsFrom`, `_readIdleNanosecondsFromProperties`, the `_ioKit` / `_coreFoundation` lookups
- `test/macos_iokit_idle_source_test.dart`

## Reference behaviour
- Apple IOKit `IOHIDSystem` `HIDIdleTime` — binding; Apple docs summarized, IOKit SDK headers raw ([thegraph.md](../../agents/thegraph.md)): settles the ownership rules and the property's unit and width.

## Cross-cutting invariants
- [Failed read reads as active](../invariant/failed-read-reads-as-active.md) — any failed step returns null, which `idleFromNanoseconds` maps to 0.
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — the ns → ms conversion is this binding's share.

## Blast radius
- [on-device-verification](on-device-verification.md) — the only place IOKit is opened, under the example's App Sandbox; the read's own cost (a few ms) is why the test bounds growth by two windows.
- [dart-ci-gates](dart-ci-gates.md) — same `coverage:ignore` hazard as Windows.

## Known holes / open
- The class doc still calls it "One of two candidates; the other is `MacOsCoreGraphicsIdleSource`" and refers to "the measurement in #22"; that class was removed in `4f6db15`. Left as is; listed in the hub's findings.
- A leak in the walk is invisible to every test: Linux never runs it, and the integration test checks values, not retain counts.
