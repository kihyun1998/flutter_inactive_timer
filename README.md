# Flutter Inactive Timer

A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). This plugin provides customizable timeout and notification thresholds, making it ideal for implementing security features like automatic logout or session timeouts.

## Features
 
- 🖥️ Supports Windows and macOS platforms
- ⏱️ Customizable inactivity timeout duration
- 🔔 Configurable notification threshold before timeout occurs
- 🔁 `onActive` callback for reacting when the user returns from inactivity
- 🔄 Easy-to-use API to start and stop monitoring
- 🛡️ Option to require explicit user confirmation to continue session

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_inactive_timer: ^1.2.0
```

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

// Stop monitoring when no longer needed
inactivityTimer.stopMonitoring();
```

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

It's recommended to start/stop monitoring based on your app's lifecycle:

```dart
@override
void initState() {
  super.initState();
  inactivityTimer = FlutterInactiveTimer(/* ... */);
  inactivityTimer.startMonitoring();
}

@override
void dispose() {
  inactivityTimer.stopMonitoring();
  super.dispose();
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

This plugin uses platform-specific APIs to detect user activity:

- On Windows, it uses the Win32 API's `GetLastInputInfo` function to track user input
- On macOS, it uses IOKit's `HIDIdleTime` to monitor user inactivity
- The plugin tracks mouse movements, keyboard actions, and other input events to determine user activity

## Roadmap

- Improve configuration options
- Add support for additional platforms in the future

## Troubleshooting

### Common Issues

1. **Timer not triggering**: Make sure your app is running on a supported platform (Windows or macOS).
2. **Inconsistent behavior**: Make sure `startMonitoring()` is called before expecting the timer to work.
3. **macOS permission issues**: Some macOS environments might require additional permissions for input monitoring.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.