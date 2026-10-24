# Publishing

## What it is
Shipping the package to pub.dev: the root manifest's constraints, what the
archive contains, the CHANGELOG and README migration sections consumers read,
and the version line. Rarely touched, irreversible when wrong.

## Governing decisions
- [ADR-0005](../../adr/0005-pure-dart-package.md) — pure Dart, name kept for continuity on pub.dev.
- [ADR-0001](../../adr/0001-idle-duration-channel-contract.md), [ADR-0002](../../adr/0002-notification-trigger-and-duration.md) — each breaking change shipped as a major bump with a migration line.

## Design model
- **`.pubignore` replaces `.gitignore` for the archive** — when present, pub ignores `.gitignore`, so build output must be listed explicitly. A copied `.pubignore` once shipped a 42 MB test DLL in a 64 MB package (commit `db4a8be`, [lessons](../../agents/lessons.md)). `docs/` is excluded, which is why README links ADRs by absolute GitHub URL.
- **A breaking change ships a copy-pasteable migration line** in CHANGELOG and a README *Migrating to x* section (3.0.0 and 4.0.0 precedents in both files).
- **Constraints are consumers' floors**: the root has no committed lockfile (`git ls-files` lists only `example/` and `example_cli/` lockfiles), so raising a caret narrows every consumer's resolution (#33's Dependabot rationale).
- **Publishing is the maintainer's act** — the agent does not run `pub publish` (`docs/agents/theflow.md` Step 7, stated policy).

## Code
- `pubspec.yaml` — `version`, `environment`, `dependencies` (`ffi`, `meta`)
- `.pubignore`
- `CHANGELOG.md`, `README.md` — *Migrating to …* sections
- `LICENSE`

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [dart-ci-gates](dart-ci-gates.md) — a new dependency must resolve without Flutter.
- [example-consumers](example-consumers.md) — both examples depend on the root by path; a public API change must be shown in use there (#10, [lessons](../../agents/lessons.md)).
- [platform-seam](platform-seam.md), [notification-timing](notification-timing.md), [remaining-countdown](remaining-countdown.md) — the public surface whose changes this territory versions.

## Known holes / open
- Nothing reports a dependency release that falls outside a caret; #33 proposes Dependabot for the root, `example/`, `example_cli/` and the workflow actions. Tracked: #33.
