# Flutter Inactive Timer

[![CI](https://github.com/kihyun1998/flutter_inactive_timer/actions/workflows/ci.yml/badge.svg)](https://github.com/kihyun1998/flutter_inactive_timer/actions/workflows/ci.yml)

A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). This plugin provides customizable timeout and notification thresholds, making it ideal for implementing security features like automatic logout or session timeouts.

## Features
 
- 🖥️ Supports Windows and macOS platforms
- ⏱️ Customizable inactivity timeout duration
- 🔔 Notification either at a percentage of the timeout or a fixed lead time before it
- ⏳ `remaining()` for driving a live countdown ("logs out in 04:59")
- 🔁 `onActive` callback for reacting when the user returns from inactivity
- 🔄 Easy-to-use API to start, stop, and dispose monitoring
- 🧹 `dispose()` for deterministic teardown (no leaked timers)
- 🛡️ Option to require explicit user confirmation to continue session

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_inactive_timer: ^3.0.0
```

> **Upgrading from 2.x?** See [Migrating to 3.0.0](#migrating-to-300) below.

## Usage

### Basic Setup

```dart
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';

// Create an instance with custom settings
final inactivityTimer = FlutterInactiveTimer(
  timeoutDuration: Duration(minutes: 5),
  notification: NotifyAtPercent(80), // notify at 80% of the timeout (i.e. 4 min)
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

### Notification Timing

The `notification` parameter decides **when** the pre-timeout warning fires. It
is a `NotificationTrigger`, one of:

```dart
// At a percentage of the timeout — here 80% of 5 minutes = 4 minutes.
notification: NotifyAtPercent(80),

// A fixed lead time before the timeout, independent of its length —
// here always 30 seconds before the timeout, whatever the timeout is.
notification: NotifyBefore(Duration(seconds: 30)),

// No notification at all — only onInactiveDetected fires, at the timeout.
notification: null, // (or omit it entirely; null is the default)
```

Use `NotifyBefore` when the warning should give the user a **constant** amount
of time to react (e.g. "always warn 1 minute before logout"), regardless of how
long the timeout is. Use `NotifyAtPercent` when the warning should scale with
the timeout.

> `NotifyBefore(before)` requires `before` to be `>= 0` and shorter than
> `timeoutDuration` (asserted in debug builds). A lead time equal to or longer
> than the timeout has no valid firing point, so in release it safely fires at
> the moment monitoring starts.

### Advanced Usage

#### Reacting to User Return (`onActive`)

`onActive` fires once when the user becomes active again **after** a notification
has already been delivered. It lets you clean up any UI state that was put in
place by `onNotification` (a warning banner, a dimmed overlay, a status label,
etc.) without having to track it yourself.

```dart
final inactivityTimer = FlutterInactiveTimer(
  timeoutDuration: Duration(minutes: 5),
  notification: NotifyAtPercent(80),
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
  timeoutDuration: Duration(minutes: 5),
  notification: NotifyAtPercent(80),
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

#### Live Countdown (`remaining()`)

`remaining()` returns how much time is left before the timeout — use it to show
a live "logs out in `04:59`" countdown. It reads the current idle duration, so
the countdown resets when the user is active, and stays correct in
`requireExplicitContinue` lock (where computing `timeout - idle` yourself would
not). It returns `Duration.zero` when not monitoring.

It is a **pull** API: the plugin keeps no ticker of its own, so drive it from
your own periodic timer and repaint at whatever cadence you like.

```dart
Timer? _ticker;
Duration _remaining = Duration.zero;

void _startCountdown() {
  _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
    final left = await inactivityTimer.remaining();
    if (mounted) setState(() => _remaining = left);
  });
}

@override
void dispose() {
  _ticker?.cancel(); // always cancel your ticker
  inactivityTimer.dispose();
  super.dispose();
}
```

Prefer a `Stream` (e.g. for a `StreamBuilder`)? Wrap the same call — no extra
plugin API needed:

```dart
final countdown = Stream.periodic(
  const Duration(seconds: 1),
  (_) => inactivityTimer.remaining(),
).asyncMap((future) => future);
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

## Migrating to 3.0.0

`3.0.0` changes the constructor's public API:

- **`notificationPer` (int) → `notification` (`NotificationTrigger?`).** Wrap the
  old percentage in `NotifyAtPercent`, and replace `notificationPer: 0` (the old
  "no notification" value) with `null` or by omitting the parameter.
- **`timeoutDuration` (int seconds) → `Duration`.**

```dart
// 2.x
FlutterInactiveTimer(
  timeoutDuration: 300,
  notificationPer: 80,
  onInactiveDetected: ...,
  onNotification: ...,
);

// 3.0.0
FlutterInactiveTimer(
  timeoutDuration: Duration(seconds: 300),
  notification: NotifyAtPercent(80),
  onInactiveDetected: ...,
  onNotification: ...,
);
```

You can also now schedule the notification a fixed time before the timeout with
`NotifyBefore(Duration(...))` — see [Notification Timing](#notification-timing).
See [ADR-0002](https://github.com/kihyun1998/flutter_inactive_timer/blob/main/docs/adr/0002-notification-trigger-and-duration.md)
for the design rationale.

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