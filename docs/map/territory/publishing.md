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
- **Dependabot splits by what ships** (`.github/dependabot.yml`): the root is weekly with `increase-if-necessary` and one PR per dependency, because with no lockfile a PR opens only when a release falls outside a caret, and each such PR is a floor decision for consumers. `example/`, `example_cli/` and the workflow actions get one grouped PR a month, since nothing ships from them. Every PR is labelled `needs-triage` (#33).
- Before a release, run `pub-ready`.

## Code
- `pubspec.yaml` — `version`, `environment`, `dependencies` (`ffi`, `meta`)
- `.pubignore`
- `.github/dependabot.yml`
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
- Whether Dependabot's first run succeeded is visible only on GitHub (Insights → Dependency graph → Dependabot); a configuration error shows nowhere in the repo.
