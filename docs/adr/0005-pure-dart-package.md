# A pure Dart package, not a Flutter package

## Status

accepted

## Context and decision

Once the idle duration was read through `dart:ffi` (ADR-0004), the only thing
still reaching for Flutter was the seam itself: `FlutterInactiveTimerPlatform`
extended `PlatformInterface` from `plugin_platform_interface`, and the tests ran
on `flutter_test`. Everything that does the actual work — `InactivityPolicy`,
the timer, the `Stopwatch` clock, the FFI bindings — was already plain Dart.

We decided to **drop the `flutter` and `plugin_platform_interface`
dependencies** and become an ordinary Dart package.

The gain is not saving a dependency line. It is that inactivity detection stops
being a Flutter-only capability: a Dart CLI or server program can now use it,
and `example_cli/` is exactly that — the same timer, run with `dart run`, with
no Flutter SDK anywhere in the resolution.

The package keeps its name. Renaming would cost every existing user their
upgrade path for a cosmetic gain, and the name is where it is on pub.dev.

### What the seam gives up

`plugin_platform_interface` exists to enforce one rule at runtime: implementers
must `extend` the interface rather than `implement` it, so that adding a member
later does not silently break them. It does this with a token checked in the
setter.

The rule survives; the enforcement does not. `getIdleDuration()` keeps a default
body, so an `extends` subclass still compiles when the interface grows. An
`implements` subclass breaks — but at compile time, visibly, which is the
failure the token was protecting against turning into a silent one. The class
documentation states the rule plainly. Pretending the setter still guards
something would be worse than saying it does not.

### ADR-0003 is still not being revisited

`remaining()` stays `Future<Duration>`. ADR-0004 already noted that an FFI read
is synchronous, so the reason ADR-0003 gives for being async no longer holds and
a synchronous `remaining()` has become possible. That remains true and remains
out of scope: this change is about what the package depends on, not what it
exposes. Bundling a signature change into it would mean a regression could not
be attributed to either.

## Considered options

- **Keep `plugin_platform_interface` alone**, dropping only `flutter`. Rejected:
  it is the *only* remaining reason the package would be Flutter-shaped, it
  exists to solve a federated-plugin problem this package no longer has, and
  keeping it would leave the pure-Dart claim technically false.
- **Split into `inactive_timer` (pure Dart) and a Flutter wrapper.** Rejected:
  there is nothing for the wrapper to do. The public API contains no Flutter
  types, so the same package serves both audiences unchanged.
- **Take the synchronous `remaining()` at the same time.** Rejected: see above —
  one change per release, so a regression points somewhere.

## Consequences

- Usable from Dart CLI and server programs, not only Flutter apps.
- **The test suite runs on `dart test`, not `flutter test`.** Coverage comes
  from `dart test --coverage` plus `package:coverage`'s `format_coverage`, which
  needs **`--check-ignore`** to honour the `coverage:ignore` regions around the
  FFI plumbing — without that flag those unreachable lines re-enter the
  denominator and sink the gate.
- **The Dart CI job installs no Flutter.** That is deliberate: a job with
  Flutter available would let a Flutter-only dependency return without the gate
  noticing.
- Custom `FlutterInactiveTimerPlatform` subclasses no longer need
  `MockPlatformInterfaceMixin`; they extend the class directly. Anything that
  `implements` it instead will fail to compile.
- Linting moved from `flutter_lints` to `lints`.
- The example Flutter app is unchanged and still the primary example; the CLI
  example exists to keep the Flutter-free claim honest, and CI runs it on both
  desktop platforms.
