# CLAUDE.md

## Working discipline — theflow

Substantive changes (bug fix / feature / behavior change) follow the **`theflow`**
skill — run `/theflow` at the start. This repo's bindings (module map, reference
routing, boundary rule, proof methods, surfaces, gate matrix) live in
**`docs/agents/theflow.md`**; the per-incident evidence in
**`docs/agents/lessons.md`**. Read both before starting; add new war-stories to
lessons.

## Identity & invariants (the boundary)

`flutter_inactive_timer` is a cross-platform (**macOS / Windows**) Flutter
**plugin** that detects user inactivity — no keyboard or mouse input — and fires
a **Notification** (warning threshold) and an **Inactive** (timeout) callback.
The full domain language lives in **`CONTEXT.md`**; decisions in **`docs/adr/`**.

- **Functional core / imperative shell.** `InactivityPolicy` (`lib/src/`) is the
  **pure** decision rule — given (idle duration, config, whether a Notification
  fired) it returns a sealed `InactivityDecision`; it owns no timer and makes no
  platform calls. `FlutterInactiveTimer` is the **shell** (time, channel, timer,
  generation). New decision rules are covered by pure policy tests.
- **Native returns one `Idle duration` (ADR-0001)** — not two clocks subtracted in
  Dart (the Windows 32-bit input clock wraps every ~49.7 days).
- **`NotificationTrigger` is sealed (ADR-0002)** — `NotifyAtPercent` /
  `NotifyBefore`, never both; the shell resolves it to one ms offset before the
  policy, which stays agnostic to the kind.
- **`remaining()` is `Future<Duration>` (ADR-0003)** — a sync getter can't read a
  fresh idle value.
- **Recurring hazard — after `await`, the world may have changed.** The plugin is
  a timer over async native reads; `stop`/`continue`/`dispose` can land during an
  `await`. Re-check every state read at the resume point (`isMonitoring`,
  `generation`, `mounted`) and add a race-reproducing test. Four same-shaped bugs
  came from skipping this (see `docs/agents/lessons.md`).

## Agent skills

### Issue tracker
Issues live in this repo's GitHub Issues (`kihyun1998/flutter_inactive_timer`),
managed via the `gh` CLI. External PRs are **not** a triage surface. See
`docs/agents/issue-tracker.md`.

### Triage labels
Canonical label vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix` (no overrides). See `docs/agents/triage-labels.md`.

### Domain docs
Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See
`docs/agents/domain.md`.
