# Native channel returns idle duration, not two clock values

## Status

accepted

## Context and decision

The plugin originally exposed two method-channel calls, `getSystemTickCount` and `getLastInputTime`, and the Dart side subtracted one from the other to compute how long the user had been inactive. On Windows these two values came from different clocks — `getSystemTickCount` from the 64-bit `GetTickCount64`, `getLastInputTime` from the 32-bit `GetLastInputInfo.dwTime`, which wraps every ~49.7 days. After that much uptime the subtraction produced garbage. macOS happened to keep both on the same `systemUptime` reference, so the contract was implicit and unenforced.

We decided the native side will instead compute and return the **idle duration** (milliseconds since the last user input) directly, as a single value. Dart no longer subtracts two clocks — the leaky "two clock domains" contract is removed entirely rather than patched.

## Considered options

- **Normalize Windows to a 64-bit last-input timestamp** (reconstruct the high 32 bits from `GetTickCount64`), keeping the two-call contract. Rejected: it patches the wraparound but leaves the fragile "compare two clocks in Dart" contract in place.
- **Return idle duration from native (chosen).** Each platform computes idle in its own native clock, where the subtraction is naturally correct, and hands Dart a single unambiguous number.

## Consequences

- The Dart state machine (`InactivityPolicy`) is designed around idle duration, not absolute timestamps.
- This is a breaking change to the method-channel contract, shipped with a major version bump.
- Any future platform implementation must return idle-since-last-input in milliseconds, not a raw clock reading.
