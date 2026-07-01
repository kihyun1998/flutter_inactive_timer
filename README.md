# Flutter Inactive Timer

A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). This plugin provides customizable timeout and notification thresholds, making it ideal for implementing security features like automatic logout or session timeouts.

## Features
 
- 🖥️ Supports Windows and macOS platforms
- ⏱️ Customizable inactivity timeout duration
- 🔔 Configurable notification threshold before timeout occurs
- 🔁 `onActive` callback for reacting when the user returns from inactivity
- 🔄 Easy-to-use API to start, stop, and dispose monitoring
- 🧹 `dispose()` for deterministic teardown (no leaked timers)
- 🛡️ Option to require explicit user confirmation to continue session

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_inactive_timer: ^2.0.0
```

> **Upgrading from 1.x?** See [Migrating to 2.0.0](#migrating-to-200) below.

## Usage

### Basic Setup

```dart
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';

// Create an instance with custom settings
final inactivityTimer = FlutterInactiveTimer(
  timeoutDuration: 300, // 5 minutes in seconds
  notificationPer: 80, // Show notification when 80% of timeout has elapsed
  onInactiveDetected: () {
    // Handle inactive timeout, e.g., log out the user
    print('User inactive for too long. Session expired.');
  },
  onNotification: () {
    // Handle pre-timeout notification, e.g., show a warning dialog
    print('Warning: Session will expire soon due to inactivity.');
  },
  onActive: () {
    // Optional: handle the user returning after a notification was shown
    // (e.g., dismiss the warning dialog/snackbar)
    print('User is active again.');
  },
);

// Start monitoring
await inactivityTimer.startMonitoring();

// Pause monitoring (can be resumed later with startMonitoring())
inactivityTimer.stopMonitoring();

// Permanently tear down when you're done with the instance
inactivityTimer.dispose();
```

> `stopMonitoring()` is a **pause** — you can call `startMonitoring()` again.
> `dispose()` is **permanent** — it cancels the timer and releases the instance
> so it can be garbage collected; a disposed timer cannot be restarted. Always
> `dispose()` from your widget's `State.dispose`.

### Advanced Usage

#### Reacting to User Return (`onActive`)

`onActive` fires once when the user becomes active again **after** a notification
has already been delivered. It lets you clean up any UI state that was put in
place by `onNotification` (a warning banner, a dimmed overlay, a status label,
etc.) without having to track it yourself.

```dart
final inactivityTimer = FlutterInactiveTimer(
  timeoutDuration: 300,
  notificationPer: 80,
  onNotification: () => setState(() => _status = 'Almost inactive'),
  onActive: () => setState(() => _status = 'Active'),
  onInactiveDetected: () => setState(() => _status = 'Session expired'),
);
```

When does it fire?

- `requireExplicitContinue: false` (default): fires automatically as soon as the
  plugin detects fresh input (bounded to a ~500ms detection latency).
- `requireExplicitContinue: true`: fires when you call `continueSession()`.

It does **not** fire if no notification was pending (for example, resetting the
timer during normal activity will not call `onActive`).

#### Explicit Continue Mode

You can require users to explicitly confirm they want to continue their session after receiving a notification:

```dart
final inactivityTimer = FlutterInactiveTimer(
  timeoutDuration: 300,
  notificationPer: 80,
  onInactiveDetected: handleTimeout,
  onNotification: showWarningDialog,
  requireExplicitContinue: true, // Require explicit user action to continue
);
```

When using `requireExplicitContinue: true`, you'll need to call `continueSession()` method when the user confirms they want to continue:

```dart
// Example using a dialog with a continue button
void showWarningDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Session Expiring Soon'),
      content: Text('Your session will expire due to inactivity. Do you want to continue?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            inactivityTimer.continueSession(); // Explicitly continue the session
          },
          child: Text('Continue Session'),
        ),
      ],
    ),
  );
}
```

### Lifecycle Management

Tie the timer to your widget's lifecycle. Use `dispose()` (not just
`stopMonitoring()`) in `State.dispose` so the recurring timer doesn't keep the
instance — and any state its callbacks capture — alive:

```dart
@override
void initState() {
  super.initState();
  inactivityTimer = FlutterInactiveTimer(/* ... */);
  inactivityTimer.startMonitoring();
}

@override
void dispose() {
  inactivityTimer.dispose(); // permanent teardown; releases the timer
  super.dispose();
}
```

If you rebuild the timer with new settings, `dispose()` the old instance before
replacing it so its timer callback stops holding the previous object:

```dart
void reconfigure() {
  inactivityTimer.dispose();
  inactivityTimer = FlutterInactiveTimer(/* new settings */);
  inactivityTimer.startMonitoring();
}
```

## Example

Check the `/example` directory for a complete example application demonstrating all features. The example includes:

- Single mode demo showing basic timeout functionality
- Multi-mode demo showing how to use multiple independent timers
- Complete UI for configuring and testing timer settings
- Examples for both Windows and macOS platforms

## Platform Support

| Platform | Support |
|----------|---------|
| Windows  | ✅      |
| macOS    | ✅      |
| Linux    | ❌      |
| Web      | ❌      |
| Android  | ❌      |
| iOS      | ❌      |

## How It Works

Each platform computes an **idle duration** — the milliseconds since the user's
last keyboard or mouse input — and exposes it to Dart through a single
`getIdleDuration()` method channel call:

- On Windows, it derives idle time from the Win32 `GetLastInputInfo` and
  `GetTickCount64` APIs.
- On macOS, it reads IOKit's `HIDIdleTime`.

The Dart side never subtracts two separate clock readings, which avoids a class
of wraparound bugs (see [ADR-0001](https://github.com/kihyun1998/flutter_inactive_timer/blob/main/docs/adr/0001-idle-duration-channel-contract.md)).
The scheduling and notification rules live in a pure, unit-tested
`InactivityPolicy`.

## Roadmap

- Improve configuration options
- Add support for additional platforms in the future

## Troubleshooting

### Common Issues

1. **Timer not triggering**: Make sure your app is running on a supported platform (Windows or macOS).
2. **Inconsistent behavior**: Make sure `startMonitoring()` is called before expecting the timer to work.
3. **macOS permission issues**: Some macOS environments might require additional permissions for input monitoring.

## Migrating to 2.0.0

`2.0.0` is a behavior- and API-compatible upgrade **for typical app usage** —
the `FlutterInactiveTimer` constructor and its callbacks are unchanged. Two
things to know:

- **Recommended:** switch `State.dispose` from `stopMonitoring()` to
  `dispose()` (see [Lifecycle Management](#lifecycle-management)). `dispose()`
  is the new, permanent teardown that prevents leaked timers.
- **Only if you wrote a custom platform implementation:** the method channel
  contract changed. Implement `getIdleDuration()` (milliseconds since last
  input) instead of the old `getSystemTickCount()` + `getLastInputTime()` pair.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.