# Flutter Inactive Timer

A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). This plugin provides customizable timeout and notification thresholds, making it ideal for implementing security features like automatic logout or session timeouts.

## Features
 
- 🖥️ Supports Windows and macOS platforms
- ⏱️ Customizable inactivity timeout duration
- 🔔 Configurable notification threshold before timeout occurs
- 🔄 Easy-to-use API to start and stop monitoring
- 🛡️ Option to require explicit user confirmation to continue session

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_inactive_timer: ^1.1.1
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
);

// Start monitoring
await inactivityTimer.startMonitoring();

// Stop monitoring when no longer needed
inactivityTimer.stopMonitoring();
```

### Advanced Usage

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