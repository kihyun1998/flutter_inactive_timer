# theflow bindings (flutter_inactive_timer)

Project-specific data for the `theflow` skill. The skill holds the portable
*method*; this file holds the *bindings*. Per-incident evidence lives in
[`lessons.md`](lessons.md).

Identity and the domain language live in **`CONTEXT.md`** (Monitoring · Inactive ·
Notification · NotificationTrigger · Idle duration · InactivityPolicy ·
InactivityDecision). Decisions live in **`docs/adr/`** (0001 native single-clock,
0002 sealed NotificationTrigger, 0003 async `remaining()`).

## The recurring failure here: after `await`, the world already changed

This plugin is a **timer over asynchronous native reads.** While an
`await getIdleDuration()` is in flight, the caller can `stopMonitoring()` /
`continueSession()` / `dispose()`. The **same-shaped bug happened four times**
(07ac425, 9759514, 8c03f6f/#5, a6abd0f). **When you add or move an `await`,
re-check every state you read at the resume point** — `isMonitoring`,
`generation`, `mounted` — and add a test that reproduces the race
(`test/ghost_timer_test.dart`'s `GatedIdlePlatform` parks a read where you want it).

## Crate / module map

**Pure Dart, no native code and no Flutter dependency** — 4.0.0 deleted the
`windows/`/`macos/` trees, their gtest/XCTest harnesses and the plugin
declaration (ADR-0004); 4.0.0 also dropped `flutter` and `plugin_platform_interface`
themselves (ADR-0005). The FFI bindings are the one thing the Dart CI job cannot
see, so they are covered on-device instead (Step 7).

| Module | Role |
|---|---|
| `lib/flutter_inactive_timer.dart` | `FlutterInactiveTimer` — the **imperative shell**: start/stop/continue, the timer, the platform read, `remaining()`, the generation counter |
| `lib/flutter_inactive_timer_platform_interface.dart` | the seam — a plain abstract class since 4.0.0; default instance is the FFI adapter. **Extend, never implement** (the runtime token that enforced this is gone) |
| `lib/flutter_inactive_timer_ffi.dart` | `FfiFlutterInactiveTimer` — the FFI platform adapter, plus the public surface of the sources |
| `lib/src/ffi/` | one `IdleSource` per binding, one file each; `idle_sources.dart` resolves them **as a pure function of the OS name** so every arm is testable off-host. Each binding keeps its arithmetic and failure rule in a pure static, leaving only decision-free plumbing under `coverage:ignore` |
| `lib/src/inactivity_policy.dart` | **`InactivityPolicy`** — the pure **functional core** (decision rule) + sealed `InactivityDecision` |
| `lib/src/notification_trigger.dart` | sealed **`NotificationTrigger`** (`NotifyAtPercent` / `NotifyBefore`) |
| `example/integration_test/` | the **only** place an FFI binding executes — asserts the idle clock advances in step with wall-clock time while there is no input |
| `example_cli/` | a Flutter-free consumer, run by CI on both desktops so the pure-Dart claim cannot quietly stop being true |

## Step 1 — reference routing table

| Change type | Real source to read |
|---|---|
| **Native inactivity read** | the **native API docs/source** directly. `GetLastInputInfo.dwTime` is a **32-bit** value that **wraps every ~49.7 days** — Dart-side subtraction after that returns garbage; macOS `systemUptime` happens to share a base (ADR-0001). Verify per platform, do not assume symmetry |
| **FFI binding** | the **OS symbol's own docs** for signature, units and ownership; then prove it against the implementation being replaced with the parity harness (`example/integration_test/idle_parity_test.dart`) rather than by reading. **Agreement is the assertion, not correctness** — that is what makes it valid on an unattended CI runner (ADR-0004) |
| **Plugin plumbing** | the `plugin_platform_interface` package + the federated-plugin pattern |
| **Published state** | `curl -s https://pub.dev/api/packages/flutter_inactive_timer` |

## Step 2 — boundary rule (functional core / imperative shell)

- **`InactivityPolicy` is the pure core** — given (idle duration, config, whether a
  Notification already fired) it returns an `InactivityDecision`. It owns no timer
  and makes no platform calls. **New decision rules are covered by pure policy
  tests; shell tests only check wiring.**
- **`FlutterInactiveTimer` is the shell** — time, channel, timer, generation.
- **Native returns one `Idle duration` (ADR-0001)** — do not subtract two clocks
  in Dart. The contract "two clocks subtracted in Dart" was deleted precisely
  because the Windows 32-bit clock wraps.
- **`NotificationTrigger` is sealed (ADR-0002)** and the shell resolves it to a
  single `notifyAtMs` **before** it reaches the policy — the policy is agnostic to
  the kind, and a new kind does not change it. Do not let "both set" become
  representable (that is why the sealed type exists).
- **`remaining()` is `Future<Duration>` (ADR-0003)** — a sync getter cannot read a
  fresh idle value, so it would miss user activity before the Notification.

## Step 4 — proof method per layer

- **Time flows through `fake_async` + an injected clock** — never actually wait.
- **Pure core**: `InactivityPolicy` decision tests. **Shell**: wiring tests at the
  public seam (a fired callback, a `remaining()` value) — not internal fields.
- **Race tests**: `GatedIdlePlatform` parks a native read at the exact point you
  want, then you interleave `stop`/`continue`. **The harness is itself a
  verification target** — #17: `releaseHeldRead` nulled `_hold` so a parked read
  could never be released, and the existing ghost-timer test could not show it
  (the generation guard discards the resumed read).
- **Native tests are separate** (Step 7) — a Dart test proves nothing about
  `windows/` or `macos/`.

## Step 5 — test-trust (coverage lies in two ways here)

- **Native code is not in the Dart coverage denominator.** `flutter test
  --coverage` sees only `lib/` — Dart can be 100% while the C++/Swift is 0-verified.
- **Line coverage hides branch gaps** (#17): the `remaining()` post-`await`
  not-monitoring guard *line* was covered, but the `Duration.zero` branch was
  never taken until a test parked the read and slipped a `stop` in.
- **Uncovered `lib/` lines are a map of the injection seams, not bugs** (#16): the
  three uncovered lines were the default empty callbacks and the default
  `Stopwatch` clock lambda — the very things tests replace by injection.

## Step 6 — behavior-describing surfaces

- **`CHANGELOG.md`** — pub.dev snapshots at publish; open a new version. A breaking
  change ships a **copy-pasteable migration line** (3.0.0: `notificationPer: 50` →
  `notification: NotifyAtPercent(50)`).
- **`README.md` / `example/`** — a new public API is proven by being *used* in the
  example (#10: `NotifyBefore` was missing from the example after ship).
- **`docs/adr/`** — an ADR's *Consequences* must be a **currently-true** sentence,
  not "what we thought then"; flip the ADR when the decision flips.
- **`CONTEXT.md` glossary** — define a new concept (`NotificationTrigger`, `Idle
  duration`, `InactivityDecision`) here first, or the code fills the blank arbitrarily.
- **`.pubignore`** — a present `.pubignore` disables git-based listing. db4a8be: a
  `.pubignore` copied from another repo listed a nonexistent `CODE.md`, so `build/`
  (a test-harness **42 MB `flutter_windows.dll`**) shipped — a **64 MB** package,
  216 KB after the fix. Excluding `docs/` also forced README's ADR links to
  absolute GitHub URLs. The pub.dev archive cannot be un-published.

## Step 7 — gate matrix (three CI jobs, Flutter pinned)

**Dart (ubuntu) — installs no Flutter, deliberately, so a Flutter-only
dependency cannot creep back unnoticed:**
```
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --check-ignore …   # --check-ignore is load-bearing
awk … coverage/lcov.info      # line coverage < 90% fails — self-contained, no Codecov
```
- **`--check-ignore` or the gate collapses.** Without it the `coverage:ignore`
  regions around the FFI plumbing — unreachable on Linux — re-enter the
  denominator.
- **A sub-package without its own `analysis_options.yaml` breaks root `dart
  format`**: it falls back to the root file and cannot resolve `package:lints`
  from its own package config. `example_cli/` carries its own copy for that
  reason.
**Windows / macOS:** `cd example && flutter test integration_test -d <windows|macos>`
(macOS also builds the app first — that build *is* a consumer's build, and it
runs the bindings under the example's App Sandbox).

- **Format runs after `pub get`** — `dart format` reads the language version from
  `package_config`; this failure only reproduces in a clean `git worktree`.
- **Coverage floor is 90, currently ~98%** — the margin permits that much silent
  regression; a coverage-lowering change says so in the PR.
  `// coverage:ignore-*` removes lines from the **denominator** (probe: `LF` 84→83).
  **Before adding one, check whether a decision is inside it** — if so the answer
  is to lift that decision into a pure function, not to exclude it (#19).
- **Touch an FFI binding → the Dart gates see none of it.** The ubuntu job never
  opens `user32.dll` or IOKit; a wrong symbol name or unit is invisible until the
  desktop jobs run. That is the whole reason `example/integration_test/` exists.
- Release: `flutter pub publish --dry-run` **0 warnings**, no
  `build/`/`.dart_tool/`/`coverage/`/`docs/`/`.github/` in the archive — **an
  archive over a few MB means something is leaking.**
- Branch → `fix|feat!(<scope>): …` → PR (`Closes #issue`) → CI green → merge.
  `flutter pub publish` is irreversible — **the agent does not run it; the user does.**

## War-story index

The per-incident evidence lives in [`lessons.md`](lessons.md), indexed by step.
