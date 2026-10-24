# Failed read reads as active

## The fact
A supported `IdleSource` whose OS call fails returns an idle duration of **0**
— the user is treated as just active. It does not throw, and it does not report
a large value.

## Why it is cross-cutting
Each binding decides this in its own pure static, against its own failure
signal; they share no helper, only the contract on `IdleSource.idleMilliseconds`.
The reason lives in a third place: the shell's `_pump` treats any thrown read as
transient and retries, so a source that throws on a *persistent* failure stalls
monitoring forever, and one that reports a large span logs the user out for an
API failure (`WindowsIdleSource.idleFromTicks` doc). Changing one binding's rule
without the others makes the same OS failure end a session on one platform and
not the other.

## Territories it holds in
- [windows-idle-binding](../territory/windows-idle-binding.md) — `WindowsIdleSource.idleFromTicks`: `succeeded ? … : 0`.
- [macos-idle-binding](../territory/macos-idle-binding.md) — `MacOsIoKitIdleSource.idleFromNanoseconds`: `if (!succeeded || nanoseconds <= 0) return 0;`.
- [idle-source-resolution](../territory/idle-source-resolution.md) — the contract, `IdleSource.idleMilliseconds` doc; `UnsupportedIdleSource` is the deliberate exception (throws).
- [monitoring-lifecycle](../territory/monitoring-lifecycle.md) — `FlutterInactiveTimer._pump`'s `catch` is what makes throwing the wrong answer.

## What a violation looks like
A source that throws on failure: monitoring silently stops progressing (retry
every second, no callback ever). A source that returns a large value: a
spurious `onInactiveDetected` on an actively used machine.

## Discovery history
- The retired C++ returned 0 on `GetLastInputInfo` failure; the FFI port kept it (#19, [lessons](../../agents/lessons.md) — "excluding from coverage also removes the rule").
- Tests: group `WindowsIdleSource.idleFromTicks on failure`; the failure cases in group `MacOsIoKitIdleSource.idleFromNanoseconds`.

## Where it will recur
Any new `IdleSource` for a supported platform. Grep: `git grep -n "succeeded" -- lib/src/ffi` should show one failure-to-zero rule per binding.
