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