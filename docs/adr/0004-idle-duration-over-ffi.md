# Idle duration is read through dart:ffi, not a method channel

## Status

accepted

## Context and decision

Everything the native side of this plugin does is one call per platform:
`GetLastInputInfo` on Windows, the HID system's idle time on macOS. Around those
two calls sit a Swift plugin class, a C++ plugin class, a podspec, a
`CMakeLists.txt`, a gtest harness that links the Flutter Windows engine, a
privacy manifest, and the method-channel registration on both sides — a build
toolchain in two languages wrapped around what is, in each case, a single
system function returning a single number.

Both of those functions live in libraries every host already has loaded. Nothing
about them requires a compiled plugin: `dart:ffi` can call them directly.

We decided to **read the Idle duration through `dart:ffi`** and delete the
native plugin code entirely.

### What this does not change

- **ADR-0001 stands.** The value crossing into Dart is still one already-computed
  Idle duration, not two clock readings to subtract. The wraparound-prone
  arithmetic moves into Dart but keeps its 32-bit semantics explicitly, which is
  a change of location, not of contract. Any future platform still has to return
  milliseconds-since-last-input.
- **ADR-0003 stands, for now.** `remaining()` stays `Future<Duration>`. An FFI
  read is synchronous, so the reason that ADR gives for being async — "a
  synchronous getter cannot read a fresh idle value" — no longer holds, and a
  synchronous `remaining()` becomes possible for the first time. We are not
  taking it here: this work is constrained to leave observable behavior
  identical, and changing a public signature is not that. Revisit separately.
- **The functional core / imperative shell split stands.** `InactivityPolicy`
  never knew where the number came from and still does not.

### How the change is verified

The constraint on this work is that behavior is *identical*, which is a claim
about agreement between the old implementation and the new one — not about
either being correct in isolation. So the FFI sources are built beside the
method-channel implementation rather than replacing it, and both are read in the
same batch and compared, by a screen in the example app and by an integration
test that ships with it.

That framing is what makes the change verifiable without a machine of each kind.
CI runners are not operated by a person, so the absolute idle duration they
report may be meaningless — but every reader consults the same OS clock, so a
meaningless value is meaningless identically for all of them, and *agreement*
remains a valid thing to assert there. The tolerance is derived from the
measured duration of the batch rather than picked as a constant: with no input,
idle time only grows, so two readings can legitimately differ by the time
between them plus each binding's rounding.

## Considered options

- **Keep the method channel.** Rejected: it is the entire reason this repository
  contains Swift, C++, CMake, a podspec and a gtest harness, and those exist to
  transport one integer.
- **Port to FFI and drop the platform-interface seam at the same time.**
  Rejected as one step: it merges "where the number comes from" with "what shape
  this package is", and a regression would not point at either. The seam is kept
  here and revisited on its own.
- **Port to FFI, choosing each platform's binding up front.** Rejected on macOS:
  there are two plausible bindings and the argument for each is theoretical.
  Both are implemented and measured against the implementation being replaced,
  and the loser is deleted.

## Consequences

- `macos/` and `windows/` are deleted, along with the native CI jobs. The build
  toolchain for consumers drops to Dart.
- **Failures move from build time to run time.** A wrong symbol name used to be
  a compiler error; it is now a crash on the user's machine when the timer first
  ticks. Bindings are therefore resolved through named `IdleSource`
  implementations whose errors say which binding failed.
- **The native code was never in the Dart coverage denominator; the FFI code
  is.** The raw binding lines cannot execute on a CI host of a different OS, so
  arithmetic and resolution are kept in pure functions that any host can test,
  and only the irreducible binding lines are excluded from coverage. Resolution
  takes the OS name as a parameter for exactly this reason.
- Web is unreachable — `dart:io` and `dart:ffi` are both unavailable there. This
  package was already Windows and macOS only, so nothing is lost, but the
  failure now surfaces at import rather than at plugin registration.
- Package identity changes from a Flutter *plugin* to an ordinary package. That
  is a breaking change for consumers' builds even though no public API moves, so
  it ships with a major version bump and a note that a clean build is required.
