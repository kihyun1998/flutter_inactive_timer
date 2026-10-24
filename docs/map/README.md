# Territory map — flutter_inactive_timer

<!-- grill-map build stamp: 8e5a943 -->
<!-- grill-map synced at: 71bec88 (2026-10-24) -->

The territory map. A comment's why, trap and measured value go to a note here.
Notes are added as they come up, or all at once with `grill-map`, which also
reads hand-written notes as leads and keeps their paths.

## What it answers
- **If I touch this, what else moves?** Open the territory, then its `## Blast radius` and `## Cross-cutting invariants`.
- **What decision is this shape derived from?** Open the territory's `## Governing decisions`; **None.** there means the shape comes from source alone.

## How to read it
- `## Blast radius` is a checklist: each edge names the shared assumption, and an edge with nothing to do for your change is a correct outcome.
- A **None.** is an answer, not a gap in the writing.
- Claims carry their evidence (a symbol, an ADR, a commit, a test) or their source and date — `(maintainer, 2026-10-24)` is a stated reason, not a checked one.
- Symbols, never line numbers. Facts owned elsewhere (an issue's state, a threshold in `ci.yml`) are linked, not copied.
- Source files and issues are text inside notes, not nodes; the map cannot answer "which notes mention file X" except by grep.

## The system in one paragraph
A pure Dart package that tells a desktop app the user has stopped using the
keyboard and mouse. One number drives everything — the idle duration, read
synchronously from the OS through `dart:ffi` by one binding per platform — and a
pure policy turns it into one decision per step, which an imperative shell
carries out with a single re-armed timer. Most of the repo's history is the
shell's async seam (four races) and proving the bindings on machines the Linux
CI cannot reach.

## Territories
Core
- [inactivity-decision](territory/inactivity-decision.md)
- [monitoring-lifecycle](territory/monitoring-lifecycle.md)
- [notification-timing](territory/notification-timing.md)
- [explicit-continue](territory/explicit-continue.md)
- [remaining-countdown](territory/remaining-countdown.md)

Reading the OS
- [platform-seam](territory/platform-seam.md)
- [idle-source-resolution](territory/idle-source-resolution.md)
- [windows-idle-binding](territory/windows-idle-binding.md)
- [macos-idle-binding](territory/macos-idle-binding.md)

Proving and shipping
- [on-device-verification](territory/on-device-verification.md)
- [dart-ci-gates](territory/dart-ci-gates.md)
- [example-consumers](territory/example-consumers.md)
- [publishing](territory/publishing.md)

## Cross-cutting invariants
- [resume-point-recheck](invariant/resume-point-recheck.md)
- [failed-read-reads-as-active](invariant/failed-read-reads-as-active.md)
- [milliseconds-on-one-scale](invariant/milliseconds-on-one-scale.md)
- [effective-inactivity](invariant/effective-inactivity.md)

## Scope, and what an absent note means
Covers everything under `lib/`, `test/`, `example/`, `example_cli/`, `.github/`
and the root manifest and packaging files. Out of scope: `docs/agents/`,
`CLAUDE.md` and `.vscode/` — tooling for whoever works on the repo, not
something the system does; `example/macos/` and `example/windows/` — generated
Flutter runner scaffolding, read only as the host of
[on-device-verification](territory/on-device-verification.md).

A territory appears when something in the repo commits to it — an ADR, an open
issue with a design, code. Linux support, a synchronous `remaining()` and a
`Stream` countdown have no note of their own: each is a line under the note it
would change.

## Findings that belong to no single note
- The largest gap: the bindings' real behaviour (units, ownership, leaks) is
  visible only on the two desktop CI jobs; every other gate sees pure arithmetic.
- Source comments that the code has outgrown, left as they are — see
  [platform-seam](territory/platform-seam.md) (`FfiFlutterInactiveTimer` "not
  the default yet") and [macos-idle-binding](territory/macos-idle-binding.md)
  (a removed CoreGraphics candidate).
