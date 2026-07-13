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

Federated Flutter **plugin** (Dart + native). No golden CI; native is tested
separately (Step 7).

| Module | Role |
|---|---|
| `lib/flutter_inactive_timer.dart` | `FlutterInactiveTimer` — the **imperative shell**: start/stop/continue, the timer, the channel, `remaining()`, the generation counter |
| `lib/flutter_inactive_timer_platform_interface.dart` | the `plugin_platform_interface` (`^2.0.2`) surface |
| `lib/flutter_inactive_timer_method_channel.dart` | the method-channel implementation |
| `lib/src/inactivity_policy.dart` | **`InactivityPolicy`** — the pure **functional core** (decision rule) + sealed `InactivityDecision` |
| `lib/src/notification_trigger.dart` | sealed **`NotificationTrigger`** (`NotifyAtPercent` / `NotifyBefore`) |
| `windows/` | C++ (`GetTickCount64`, `GetLastInputInfo`) + a **gtest** harness |
| `macos/` | Swift (`systemUptime`) + **xcodebuild** tests |

## Step 1 — reference routing table

| Change type | Real source to read |
|---|---|
| **Native inactivity read** | the **native API docs/source** directly. `GetLastInputInfo.dwTime` is a **32-bit** value that **wraps every ~49.7 days** — Dart-side subtraction after that returns garbage; macOS `systemUptime` happens to share a base (ADR-0001). Verify per platform, do not assume symmetry |
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

**Dart (ubuntu):**
```
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
awk … coverage/lcov.info      # line coverage < 90% fails — self-contained, no Codecov
```
**Windows:** `flutter precache --windows` → `cmake -S windows/test` → `ctest`
(gtest links the Flutter Windows engine + client wrapper).
**macOS:** `cd example && flutter build macos --debug` **first** (else the missing
`Flutter/ephemeral/*.xcfilelist` breaks the Xcode build) → `xcodebuild test`.

- **Format runs after `pub get`** — `dart format` reads the language version from
  `package_config`; this failure only reproduces in a clean `git worktree`.
- **Coverage floor is 90, currently 97.7% (126/129)** — the 7.7 pp permits that
  much silent regression; a coverage-lowering change says so in the PR.
  `// coverage:ignore-*` removes lines from the **denominator** (probe: `LF` 84→83).
- **Touch native → touch native tests.** The Dart gates see zero of `windows/`/`macos/`.
- Release: `flutter pub publish --dry-run` **0 warnings**, no
  `build/`/`.dart_tool/`/`coverage/`/`docs/`/`.github/` in the archive — **an
  archive over a few MB means something is leaking.**
- Branch → `fix|feat!(<scope>): …` → PR (`Closes #issue`) → CI green → merge.
  `flutter pub publish` is irreversible — **the agent does not run it; the user does.**

## War-story index

The per-incident evidence lives in [`lessons.md`](lessons.md), indexed by step.
