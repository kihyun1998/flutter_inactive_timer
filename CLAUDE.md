# CLAUDE.md

## Working discipline

Substantive changes (fix / feature / behaviour change) run **`thegraph`**; its
build for this repo is `docs/agents/thegraph.md`.

## Identity & invariants (the boundary)

`flutter_inactive_timer` is a **pure Dart package** for desktop (**macOS /
Windows**) that detects user inactivity — no keyboard or mouse input — and fires
a **Notification** (warning threshold) and an **Inactive** (timeout) callback.

- **Functional core / imperative shell.** `InactivityPolicy` (`lib/src/`) is the
  **pure** decision rule — given (idle duration, config, whether a Notification
  fired) it returns a sealed `InactivityDecision`; it owns no timer and makes no
  platform calls. `FlutterInactiveTimer` is the **shell** (time, platform read,
  timer, generation). New decision rules are covered by pure policy tests.
- **Each binding returns one `Idle duration` in ms (ADR-0001)** — never two
  clocks subtracted downstream (the Windows 32-bit input clock wraps every
  ~49.7 days).
- **`NotificationTrigger` is sealed (ADR-0002)** — `NotifyAtPercent` /
  `NotifyBefore`, never both; the shell resolves it to one ms offset before the
  policy, which stays agnostic to the kind.
- **`remaining()` is `Future<Duration>` (ADR-0003)** — a synchronous version is
  now possible and deliberately deferred (ADR-0004, ADR-0005).
- **After `await`, the world may have changed.** The platform seam is async;
  `stop`/`continue`/`dispose` can land during an `await`. Re-check every state
  read at the resume point (`isMonitoring`, `generation`, `mounted`) and add a
  race-reproducing test. See `docs/map/invariant/resume-point-recheck.md`.

## Comments

A comment says what the code is. Why it is this way, what it deliberately
leaves out, the trap and the measured value go to the territory note under
`docs/map/`. Where none seems to hold it, search the folder and the code symbol
first; only then start a new note, named for what the system does there, not
for the file. History goes to the commit message. Comments written before this
rule still carry the rest: never delete one whose content the map does not yet
hold — move it first (`decant`).

## Territory map

The map is **[`docs/map/README.md`](docs/map/README.md)**. Read the territories a
change touches — and their blast radius and invariants — before designing it;
after it lands, update the notes it made false. When a fix reveals a fact, ask
whether it holds at every site that shares the same assumption; if so, the fix
lands with an invariant note under `docs/map/invariant/`.

## Agent skills

### Issue tracker
Before filing or reading an issue, read `docs/agents/issue-tracker.md` (GitHub
Issues).

### Triage labels
Before applying a triage label, read `docs/agents/triage-labels.md`.

### Domain docs
Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. Before
naming a domain concept or contradicting a decision, read `docs/agents/domain.md`.
