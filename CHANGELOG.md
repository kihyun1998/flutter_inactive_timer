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