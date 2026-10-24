# Dart CI gates

## What it is
The Linux `Dart` job that every push and PR must pass: format, analyze, unit
tests with coverage, and a self-contained line-coverage floor. It installs no
Flutter at all.

## Governing decisions
- [ADR-0005](../../adr/0005-pure-dart-package.md) — no Flutter on this job, so a Flutter-only dependency cannot creep back.

## Design model
- **No Flutter SDK by design** — `dart pub get --no-example`, since `example/` is a Flutter app and resolving it would fail the job before any gate (commit `35c61af`; ci.yml comments).
- **`--check-ignore` is load-bearing**: without it the `coverage:ignore` regions around FFI plumbing re-enter the denominator and sink the gate (ci.yml comment, step `Format coverage`).
- **The floor lives in ci.yml** (step `Check coverage threshold`); a `coverage:ignore` shrinks the denominator, so one wrapped around a decision hides it — lift the decision into a pure static instead (#19, [lessons](../../agents/lessons.md)).
- Time in tests flows through `fake_async` and an injected clock; nothing actually waits (`test/flutter_inactive_timer_test.dart`, dev dependency `fake_async`).

## Code
- `.github/workflows/ci.yml` — job `dart`
- `analysis_options.yaml`, `example_cli/analysis_options.yaml`
- `pubspec.yaml` — `dev_dependencies` (`test`, `lints`, `fake_async`, `coverage`)

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [windows-idle-binding](windows-idle-binding.md), [macos-idle-binding](macos-idle-binding.md) — these gates never open `user32.dll` or IOKit; green here says nothing about a binding.
- [publishing](publishing.md) — a dependency that needs Flutter breaks this job first, which is the point.

## Known holes / open
- `example_cli/` carries its own `analysis_options.yaml` (added in `68e24b4`); why it needs one rather than inheriting the root's is recorded nowhere but a retired doc, and was not checked here.
- Line coverage hides branch gaps (#17: the post-`await` guard line was covered before its `Duration.zero` branch was ever taken, [lessons](../../agents/lessons.md)). No branch-coverage gate exists.
