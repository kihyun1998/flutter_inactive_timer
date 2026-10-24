# On-device verification

## What it is
The only place the FFI bindings actually execute: the example app's integration
test, run by the Windows and macOS CI jobs, plus the example's *Idle Source* tab
that shows the raw value. Everything on Linux sees only the bindings' pure
arithmetic.

## Governing decisions
- [ADR-0004](../../adr/0004-idle-duration-over-ffi.md) — verification by agreement on an unattended runner; the parity screen and test this territory descends from.

## Design model
- **Self-consistency replaced parity**: with the method-channel reference deleted, the test asserts that idle time grows in step with wall-clock time while there is no input. A binding reporting the wrong unit agrees with itself but fails this (comment in the test).
- **Input invalidates an observation, it does not fail it**: an observation is discarded when growth is short *and* the reading is small enough to have started inside the window — coherence, not sign (#23, [lessons](../../agents/lessons.md); read in the test).
- **Two windows bound the growth**: the outer stopwatch (both reads) is an upper bound on the sample gap, the inner (the delay alone) a lower bound, so no constant for read cost is needed (commit `98df999`; read in the test).
- **Tolerance is the clock's granularity**: 16 ms on Windows (15.625 ms tick, measured as 15/16 ms failures), 2 ms on macOS (`_clockGranularityMs` doc).
- Bounded retries (`_maxAttempts`) stop a source that keeps resetting from looping forever.
- macOS runs it inside the example's App Sandbox, which is the environment a shipped app runs in (ci.yml comment, macOS job).

## Code
- `example/integration_test/idle_source_test.dart` — `_clockGranularityMs`, `_observation`, `_maxAttempts`, the three `testWidgets`
- `example/lib/idle_source_demo.dart` — `IdleSourceDemo`, `_IdleSourceDemoState._read`
- `.github/workflows/ci.yml` — jobs `windows` and `macos`, step `Idle source`

## Reference behaviour
- Measured on CI, recorded in [lessons](../../agents/lessons.md) under #19 and #23 and in ADR-0004's run records.

## Cross-cutting invariants
- [Milliseconds on one scale](../invariant/milliseconds-on-one-scale.md) — this is the check that catches a unit violation.

## Blast radius
- [windows-idle-binding](windows-idle-binding.md), [macos-idle-binding](macos-idle-binding.md) — a binding change is verified only here; the tolerance encodes each binding's tick.
- [example-consumers](example-consumers.md) — the test pumps `IdleSourceDemo` from the example app, and the example's Flutter dependency is what lets it run.

## Known holes / open
- The test checks the value moves correctly; it cannot see leaks, wrong release counts, or behaviour under real input bursts.
