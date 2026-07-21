## 4.0.0

### Breaking

- **This is no longer a Flutter plugin — it is an ordinary package.** The idle
  duration is now read straight from the OS through `dart:ffi` instead of a
  method channel, so the package ships no Swift, C++, podspec or CMake, and
  your build has nothing native to compile. See ADR-0004.

  **No source changes are required.** `FlutterInactiveTimer`, its callbacks and
  `remaining()` are all unchanged, and they return the same values as before.

  Migration:
  ```
  flutter clean   # then rebuild
  ```
  A stale build directory can still carry the old plugin registration, which
  now has nothing to register.

- `MethodChannelFlutterInactiveTimer` is removed. It only matters if you wrote
  your own platform implementation: the seam is unchanged — implement
  `getIdleDuration()` on `FlutterInactiveTimerPlatform` — but the built-in
  method-channel implementation it sat next to is gone.

### Why this is safe

Both implementations were built side by side and read in the same batch on real
machines before the native code was deleted. They reported the same value to the
millisecond on Windows and on macOS, under the example app's App Sandbox. The
CI runs that established this are recorded in ADR-0004, along with a rejected
macOS alternative that was ~9ms off and did not ship.

### Internal

- Adds `FfiFlutterInactiveTimer` and one named `IdleSource` per platform
  binding: `GetLastInputInfo`/`GetTickCount64` on Windows, IOKit `HIDIdleTime`
  on macOS. Each binding's arithmetic and failure rule are pure functions, unit
  tested on any host; only the irreducible FFI plumbing is platform-bound.
- The example app's `Idle Source` tab and an on-device integration test are the
  only places the bindings execute — the Dart CI job runs on Linux and opens
  neither `user32.dll` nor IOKit. The test asserts the idle clock advances in
  step with wall-clock time while there is no input, which catches a binding
  reporting the wrong unit.
- The native CI jobs (gtest on Windows, XCTest on macOS) are removed along with
  the code they tested.

## 3.0.0

### Breaking

- The Notification's timing is now a `NotificationTrigger` passed as
  `notification:`, replacing the `notificationPer` integer. It is a sealed type
  with two kinds:
  - `NotifyAtPercent(int percent)` — fire at `percent`% of the timeout (the old
    `notificationPer` behavior).
  - `NotifyBefore(Duration before)` — fire a fixed lead time before the timeout,
    independent of its length (new).

  `notification` is optional; `null` (the default) means no Notification, only
  the timeout fires — replacing the old `notificationPer: 0`. See ADR-0002.
- `timeoutDuration` is now a `Duration` instead of an `int` number of seconds,
  so the whole API speaks one time type.

  Migration:
  ```dart
  // 2.x
  FlutterInactiveTimer(timeoutDuration: 60, notificationPer: 50, ...);
  // 3.0.0
  FlutterInactiveTimer(
    timeoutDuration: Duration(seconds: 60),
    notification: NotifyAtPercent(50),
    ...,
  );
  ```

### Features

- `NotifyBefore(Duration)` schedules the Notification a fixed lead time before
  the timeout (e.g. `NotifyBefore(Duration(seconds: 120))` on a 5-minute timeout
  fires at 3 minutes). `before` must be `>= 0` and shorter than the timeout
  (asserted in debug); a value `>=` the timeout safely clamps to firing at
  monitoring start.
- `Future<Duration> remaining()` returns the time left before timeout, for
  driving a live countdown (e.g. a "logs out in 04:59" label). It reads the
  current idle duration, so the countdown resets on user activity — and stays
  correct in `requireExplicitContinue` lock, where a naive `timeout - idle`
  would not. Returns `Duration.zero` when not monitoring. It is a *pull* API:
  drive it from your own periodic ticker; the timer keeps none of its own. See
  ADR-0003.

## 2.0.0

### Breaking

- The native method channel now exposes a single `getIdleDuration()` method (milliseconds since the last user input) in place of the previous `getSystemTickCount()` + `getLastInputTime()` pair. This removes a Windows bug where the two calls used different clock widths (64-bit `GetTickCount64` vs 32-bit `GetLastInputInfo`), producing incorrect inactivity after ~49.7 days of uptime. See ADR-0001. Custom `FlutterInactiveTimerPlatform` implementations must now implement `getIdleDuration()`.

### Features

- Added `FlutterInactiveTimer.dispose()` for deterministic teardown: it cancels the active timer and releases the instance so it (and its callbacks) can be garbage collected. Unlike `stopMonitoring()` (a resumable pause), a disposed timer cannot be restarted. Call it from your widget's `State.dispose`.

### Internal

- Extracted the scheduling and notification logic into a pure, side-effect-free `InactivityPolicy` (with a sealed `InactivityDecision`), making the timing rules unit-testable without mocking timers or the platform channel. `FlutterInactiveTimer` is now a thin shell over it.
- `FlutterInactiveTimer` gained optional `platform` and `clock` constructor parameters for dependency injection in tests; production defaults are unchanged.
- Hardened the scheduling loop with a generation guard so an in-flight check that is superseded by `stopMonitoring`/`startMonitoring`/`continueSession`/`dispose` cannot arm a stale timer. Guarantees at most one live timer under overlapping calls (regression-tested).

## 1.2.0

### Behavior fix (breaking)

- `notificationPer` now consistently means **"percent of timeout elapsed"**, matching the documented behavior. The scheduler previously interpreted it as "percent remaining", so notifications fired at the wrong time (e.g. `timeoutDuration=60, notificationPer=10` fired at 54s instead of 6s) and triggered a 1ms busy-loop whenever `per > 50`. Callers that relied on the old reversed meaning will see firing times change — adjust your `notificationPer` accordingly.

### Features

- Added optional `onActive` callback. Fires when the user becomes active again after a notification has been delivered — both on detected user input (when `requireExplicitContinue` is false) and on `continueSession()` calls. Existing constructors remain source-compatible (the parameter is optional).

### Improvements

- Post-notification scheduling now polls at a 500ms cap when `requireExplicitContinue` is false, bounding the latency between user return and `onActive` firing. Previously the next check could be scheduled up to `timeoutDuration × (100 - per)%` away, which made UI recovery feel broken on longer timeouts.
- `requireExplicitContinue=true` continues to schedule a single check at timeout (input is ignored in that mode, so polling buys nothing).

### Tests

- Rewrote the test suite with `fake_async` for real behavioral verification of timer scheduling, notification timing, user-activity reset, explicit continue, `onActive` triggers, and the 500ms polling cap.

### Example

- `MultiModeDemo` now uses `onActive` to restore the status label when the user returns, instead of leaving it stuck at "Almost inactive!".

## 1.1.4

- Fix: ensure stopMonitoring() fully stops during async inactivity checks

## 1.1.3

- update license

## 1.1.2

- update license

## 1.1.1

- update macos target version 

## 1.1.0

### macOS Support Added

- Added native macOS implementation using IOKit HIDIdleTime
- Now fully supports both Windows and macOS platforms
- Updated platform configuration in pubspec.yaml
- Added example code for macOS

## 1.0.0

### Initial Release

- Added support for detecting user inactivity in Windows desktop applications
- Implemented customizable timeout duration for inactivity detection
- Added notification threshold feature to alert users before timeout occurs
- Included callback functions for handling inactivity detection and notifications
- Implemented option to require explicit user confirmation to continue session after notification
- Added ability to start and stop inactivity monitoring
- Added continueSession method to explicitly reset timer when required