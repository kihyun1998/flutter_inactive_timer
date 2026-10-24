# Milliseconds on one scale

## The fact
The idle duration every source returns and the shell's clock are both in
**milliseconds**, because the policy compares them directly
(`idleMs < sinceResetMs`) and subtracts one from the timeout.

## Why it is cross-cutting
Each source reaches milliseconds its own way — Windows ticks are milliseconds
already, macOS divides nanoseconds — and the shell's clock reaches them through
`Stopwatch.elapsedMilliseconds`. Nothing converts at the seam; no type carries
the unit (`int`). A source in seconds or nanoseconds compiles, passes every
Linux test, and makes every input look like none (or every idle look like days).

## Territories it holds in
- [windows-idle-binding](../territory/windows-idle-binding.md) — `WindowsIdleSource.idleFromTicks` (tick difference, no conversion).
- [macos-idle-binding](../territory/macos-idle-binding.md) — `MacOsIoKitIdleSource.idleFromNanoseconds` (`~/ 1000000`).
- [monitoring-lifecycle](../territory/monitoring-lifecycle.md) — `FlutterInactiveTimer._defaultClock` and `_snapshot` (`timeoutDuration.inMilliseconds`).
- [inactivity-decision](../territory/inactivity-decision.md) — `InactivityPolicy.evaluate` compares the two.
- [idle-source-resolution](../territory/idle-source-resolution.md) — the unit is stated only in `IdleSource.idleMilliseconds`'s doc.
- [on-device-verification](../territory/on-device-verification.md) — the integration test is the only check that sees a wrong unit.

## What a violation looks like
Seconds: idle barely moves, every poll reads as fresh input, Notification never
fires. Nanoseconds: idle is huge, timeout fires at once. Neither shows on the
Linux job.

## Discovery history
- Stated as the reason the integration test checks growth against wall-clock time ("a binding returning nanoseconds or seconds … fails this immediately", comment in `example/integration_test/idle_source_test.dart`).

## Where it will recur
Any new `IdleSource`, and any replacement for the default clock. If a function
produces an `idleMs` or a `_now()` value, it is subject to this.
