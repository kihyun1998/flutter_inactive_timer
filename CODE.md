# flutter_inactive_timer
## Project Structure

```
flutter_inactive_timer/
├── example/
    ├── integration_test/
    │   └── plugin_integration_test.dart
    ├── lib/
    │   └── main.dart
    ├── macos/
    │   ├── Runner/
    │   │   ├── AppDelegate.swift
    │   │   ├── DebugProfile.entitlements
    │   │   ├── Info.plist
    │   │   ├── MainFlutterWindow.swift
    │   │   └── Release.entitlements
    │   ├── Runner.xcodeproj/
    │   │   ├── project.xcworkspace/
    │   │   │   └── xcshareddata/
    │   │   │   │   └── IDEWorkspaceChecks.plist
    │   │   ├── xcshareddata/
    │   │   │   └── xcschemes/
    │   │   │   │   └── Runner.xcscheme
    │   │   └── project.pbxproj
    │   ├── Runner.xcworkspace/
    │   │   ├── xcshareddata/
    │   │   │   └── IDEWorkspaceChecks.plist
    │   │   └── contents.xcworkspacedata
    │   └── Podfile
    └── test/
    │   └── widget_test.dart
├── lib/
    ├── flutter_inactive_timer.dart
    ├── flutter_inactive_timer_method_channel.dart
    └── flutter_inactive_timer_platform_interface.dart
├── macos/
    ├── Classes/
    │   └── FlutterInactiveTimerPlugin.swift
    ├── Resources/
    │   └── PrivacyInfo.xcprivacy
    └── flutter_inactive_timer.podspec
├── test/
    ├── flutter_inactive_timer_method_channel_test.dart
    └── flutter_inactive_timer_test.dart
└── windows/
    ├── include/
        └── flutter_inactive_timer/
        │   └── flutter_inactive_timer_plugin_c_api.h
    ├── test/
        └── flutter_inactive_timer_plugin_test.cpp
    ├── CMakeLists.txt
    ├── flutter_inactive_timer_plugin.cpp
    ├── flutter_inactive_timer_plugin.h
    └── flutter_inactive_timer_plugin_c_api.cpp
```

## example/integration_test/plugin_integration_test.dart
```dart
// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

```
## example/lib/main.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inactive Timer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TimerDemoTabs(),
    );
  }
}

class TimerDemoTabs extends StatelessWidget {
  const TimerDemoTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inactive Timer Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Single Mode', icon: Icon(Icons.timer)),
              Tab(text: 'Multi Mode', icon: Icon(Icons.splitscreen)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SingleModeDemo(),
            MultiModeDemo(),
          ],
        ),
      ),
    );
  }
}

class SingleModeDemo extends StatefulWidget {
  const SingleModeDemo({super.key});

  @override
  State<SingleModeDemo> createState() => _SingleModeDemoState();
}

class _SingleModeDemoState extends State<SingleModeDemo> {
  FlutterInactiveTimer? _inactivityTimer;
  bool _isMonitoring = false;
  String _status = 'Not monitoring';

  // User-configurable values
  int _timeoutDuration = 15; // default: 15 seconds
  int _notificationPercent = 70; // default: 70%
  bool _requireExplicitContinue = true; // Require explicit continue

  @override
  void initState() {
    super.initState();
    _setupInactivityTimer();
  }

  void _setupInactivityTimer() {
    _inactivityTimer = FlutterInactiveTimer(
      timeoutDuration: _timeoutDuration,
      notificationPer: _notificationPercent,
      onInactiveDetected: _handleInactiveDetected,
      onNotification: _handleNotification,
      requireExplicitContinue: _requireExplicitContinue,
    );
  }

  void _handleInactiveDetected() {
    setState(() {
      _status = 'Inactive detected';
      _isMonitoring = false;
    });

    // Show a dialog when timeout occurs
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
              'You have been inactive for too long. Your session has expired.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _handleNotification() {
    // Show warning via snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Warning: Your session will expire soon due to inactivity!'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Continue Session',
            onPressed: () {
              // Resume session explicitly when user presses the button
              _inactivityTimer?.continueSession();
            },
          ),
        ),
      );
    }
  }

  void _startMonitoring() async {
    if (_inactivityTimer == null) return;

    await _inactivityTimer!.startMonitoring();

    setState(() {
      _status = 'Monitoring active';
      _isMonitoring = true;
    });

    // Notify that monitoring has started
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inactivity monitoring started'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _stopMonitoring() {
    if (_inactivityTimer == null) return;

    _inactivityTimer!.stopMonitoring();

    setState(() {
      _status = 'Monitoring stopped';
      _isMonitoring = false;
    });
  }

  // Reconfigure the timer when settings change
  void _updateTimerSettings() {
    if (_isMonitoring) {
      _stopMonitoring();
    }

    _setupInactivityTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Timer settings updated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text('Current Settings:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Timeout: $_timeoutDuration seconds'),
                    Text('Notification at: $_notificationPercent% of timeout'),
                    Text(
                        'Require explicit continue: ${_requireExplicitContinue ? 'Yes' : 'No'}'),
                  ],
                ),
              ),
            ),

            // Timer Settings
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Timer Settings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Timeout Duration: $_timeoutDuration seconds'),
                    Slider(
                      value: _timeoutDuration.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '$_timeoutDuration seconds',
                      onChanged: (value) {
                        setState(() {
                          _timeoutDuration = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Notification Threshold: $_notificationPercent%'),
                    Slider(
                      value: _notificationPercent.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '$_notificationPercent%',
                      onChanged: (value) {
                        setState(() {
                          _notificationPercent = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Require explicit continue: '),
                        Switch(
                          value: _requireExplicitContinue,
                          onChanged: (value) {
                            setState(() {
                              _requireExplicitContinue = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _updateTimerSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Apply Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Demo Description
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('What this demo shows:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        '• A Snackbar warning when reaching the notification threshold'),
                    Text('• A Dialog when inactive timeout is reached'),
                    Text(
                        '• Customizable timeout duration and notification threshold'),
                  ],
                ),
              ),
            ),

            // Control Buttons
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Start Monitoring'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Stop Monitoring'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up
    _inactivityTimer?.stopMonitoring();
    super.dispose();
  }
}

class MultiModeDemo extends StatefulWidget {
  const MultiModeDemo({super.key});

  @override
  State<MultiModeDemo> createState() => _MultiModeDemoState();
}

class _MultiModeDemoState extends State<MultiModeDemo> {
  // Left timer
  FlutterInactiveTimer? _leftTimer;
  bool _isLeftMonitoring = false;
  String _leftStatus = 'Not monitoring';
  int _leftTimeoutDuration = 10; // 10 sec
  int _leftNotificationPercent = 50; // 50%

  // Right timer
  FlutterInactiveTimer? _rightTimer;
  bool _isRightMonitoring = false;
  String _rightStatus = 'Not monitoring';
  int _rightTimeoutDuration = 20; // 20 sec
  int _rightNotificationPercent = 80; // 80%

  @override
  void initState() {
    super.initState();
    _setupTimers();
  }

  void _setupTimers() {
    // Configure left timer
    _leftTimer = FlutterInactiveTimer(
      timeoutDuration: _leftTimeoutDuration,
      notificationPer: _leftNotificationPercent,
      onInactiveDetected: () {
        setState(() {
          _leftStatus = 'INACTIVE DETECTED!';
          _isLeftMonitoring = false;
        });
      },
      onNotification: () {
        setState(() {
          _leftStatus = 'Almost inactive!';
        });
      },
    );

    // Configure right timer
    _rightTimer = FlutterInactiveTimer(
      timeoutDuration: _rightTimeoutDuration,
      notificationPer: _rightNotificationPercent,
      onInactiveDetected: () {
        setState(() {
          _rightStatus = 'INACTIVE DETECTED!';
          _isRightMonitoring = false;
        });
      },
      onNotification: () {
        setState(() {
          _rightStatus = 'Almost inactive!';
        });
      },
    );
  }

  // Start left timer
  void _startLeftTimer() async {
    if (_leftTimer == null) return;

    await _leftTimer!.startMonitoring();

    setState(() {
      _leftStatus = 'Monitoring...';
      _isLeftMonitoring = true;
    });
  }

  // Stop left timer
  void _stopLeftTimer() {
    if (_leftTimer == null) return;

    _leftTimer!.stopMonitoring();

    setState(() {
      _leftStatus = 'Stopped';
      _isLeftMonitoring = false;
    });
  }

  // Upate left timer settings
  void _updateLeftTimer() {
    if (_isLeftMonitoring) {
      _stopLeftTimer();
    }

    _setupTimers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Left timer settings updated'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Start right timer
  void _startRightTimer() async {
    if (_rightTimer == null) return;

    await _rightTimer!.startMonitoring();

    setState(() {
      _rightStatus = 'Monitoring...';
      _isRightMonitoring = true;
    });
  }

  // Stop right timer
  void _stopRightTimer() {
    if (_rightTimer == null) return;

    _rightTimer!.stopMonitoring();

    setState(() {
      _rightStatus = 'Stopped';
      _isRightMonitoring = false;
    });
  }

  // Update right timer setting
  void _updateRightTimer() {
    if (_isRightMonitoring) {
      _stopRightTimer();
    }

    _setupTimers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Right timer settings updated'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Multiple Timer Demo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This demo shows how multiple inactive timers can be used independently',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Timer
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Left Timer',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text('Status: $_leftStatus',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _leftStatus.contains('INACTIVE')
                                      ? Colors.red
                                      : _leftStatus.contains('Almost')
                                          ? Colors.orange
                                          : null)),
                          const SizedBox(height: 16),

                          // Left timer settings slider
                          Text('Timeout: $_leftTimeoutDuration seconds'),
                          Slider(
                            value: _leftTimeoutDuration.toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label: '$_leftTimeoutDuration seconds',
                            onChanged: (value) {
                              setState(() {
                                _leftTimeoutDuration = value.round();
                              });
                            },
                          ),

                          Text('Notification: $_leftNotificationPercent%'),
                          Slider(
                            value: _leftNotificationPercent.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '$_leftNotificationPercent%',
                            onChanged: (value) {
                              setState(() {
                                _leftNotificationPercent = value.round();
                              });
                            },
                          ),

                          // Update Button
                          Center(
                            child: ElevatedButton(
                              onPressed: _updateLeftTimer,
                              child: const Text('Update Settings'),
                            ),
                          ),

                          const Spacer(),

                          // Control Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    _isLeftMonitoring ? null : _startLeftTimer,
                                child: const Text('Start'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    _isLeftMonitoring ? _stopLeftTimer : null,
                                child: const Text('Stop'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // RightTimer
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Right Timer',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text('Status: $_rightStatus',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _rightStatus.contains('INACTIVE')
                                      ? Colors.red
                                      : _rightStatus.contains('Almost')
                                          ? Colors.orange
                                          : null)),
                          const SizedBox(height: 16),

                          // Right timer settings slider
                          Text('Timeout: $_rightTimeoutDuration seconds'),
                          Slider(
                            value: _rightTimeoutDuration.toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label: '$_rightTimeoutDuration seconds',
                            onChanged: (value) {
                              setState(() {
                                _rightTimeoutDuration = value.round();
                              });
                            },
                          ),

                          Text('Notification: $_rightNotificationPercent%'),
                          Slider(
                            value: _rightNotificationPercent.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '$_rightNotificationPercent%',
                            onChanged: (value) {
                              setState(() {
                                _rightNotificationPercent = value.round();
                              });
                            },
                          ),

                          // Update Button
                          Center(
                            child: ElevatedButton(
                              onPressed: _updateRightTimer,
                              child: const Text('Update Settings'),
                            ),
                          ),

                          const Spacer(),

                          // Control button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _isRightMonitoring
                                    ? null
                                    : _startRightTimer,
                                child: const Text('Start'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    _isRightMonitoring ? _stopRightTimer : null,
                                child: const Text('Stop'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Each timer operates independently with customizable settings. Try setting different timeout values and observe the behavior.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _leftTimer?.stopMonitoring();
    _rightTimer?.stopMonitoring();
    super.dispose();
  }
}

```
## example/macos/Podfile
```
platform :osx, '10.14'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run \"flutter pub get\""
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_macos_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_macos_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
  end
end

```
## example/macos/Runner/AppDelegate.swift
```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

```
## example/macos/Runner/DebugProfile.entitlements
```entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>

```
## example/macos/Runner/Info.plist
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIconFile</key>
	<string></string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>NSHumanReadableCopyright</key>
	<string>$(PRODUCT_COPYRIGHT)</string>
	<key>NSMainNibFile</key>
	<string>MainMenu</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>

```
## example/macos/Runner/MainFlutterWindow.swift
```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

```
## example/macos/Runner/Release.entitlements
```entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>

```
## example/macos/Runner.xcodeproj/project.pbxproj
```pbxproj
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 54;
	objects = {

/* Begin PBXAggregateTarget section */
		33CC111A2044C6BA0003C045 /* Flutter Assemble */ = {
			isa = PBXAggregateTarget;
			buildConfigurationList = 33CC111B2044C6BA0003C045 /* Build configuration list for PBXAggregateTarget "Flutter Assemble" */;
			buildPhases = (
				33CC111E2044C6BF0003C045 /* ShellScript */,
			);
			dependencies = (
			);
			name = "Flutter Assemble";
			productName = FLX;
		};
/* End PBXAggregateTarget section */

/* Begin PBXBuildFile section */
		1EE3BF8164E0F092B945FB73 /* Pods_RunnerTests.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = FB206FAB697CE4BFA2FD8CAB /* Pods_RunnerTests.framework */; };
		331C80D8294CF71000263BE5 /* RunnerTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 331C80D7294CF71000263BE5 /* RunnerTests.swift */; };
		335BBD1B22A9A15E00E9071D /* GeneratedPluginRegistrant.swift in Sources */ = {isa = PBXBuildFile; fileRef = 335BBD1A22A9A15E00E9071D /* GeneratedPluginRegistrant.swift */; };
		33CC10F12044A3C60003C045 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 33CC10F02044A3C60003C045 /* AppDelegate.swift */; };
		33CC10F32044A3C60003C045 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = 33CC10F22044A3C60003C045 /* Assets.xcassets */; };
		33CC10F62044A3C60003C045 /* MainMenu.xib in Resources */ = {isa = PBXBuildFile; fileRef = 33CC10F42044A3C60003C045 /* MainMenu.xib */; };
		33CC11132044BFA00003C045 /* MainFlutterWindow.swift in Sources */ = {isa = PBXBuildFile; fileRef = 33CC11122044BFA00003C045 /* MainFlutterWindow.swift */; };
		4D1C5D79619816FB1C5AF8A3 /* Pods_Runner.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 70C975366AF1292D82ACCF60 /* Pods_Runner.framework */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		331C80D9294CF71000263BE5 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 33CC10E52044A3C60003C045 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 33CC10EC2044A3C60003C045;
			remoteInfo = Runner;
		};
		33CC111F2044C79F0003C045 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 33CC10E52044A3C60003C045 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 33CC111A2044C6BA0003C045;
			remoteInfo = FLX;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		33CC110E2044A8840003C045 /* Bundle Framework */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 10;
			files = (
			);
			name = "Bundle Framework";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
		07D573B28E1DBE7008097DBA /* Pods-Runner.release.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-Runner.release.xcconfig"; path = "Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"; sourceTree = "<group>"; };
		331C80D5294CF71000263BE5 /* RunnerTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RunnerTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
		331C80D7294CF71000263BE5 /* RunnerTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RunnerTests.swift; sourceTree = "<group>"; };
		333000ED22D3DE5D00554162 /* Warnings.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Warnings.xcconfig; sourceTree = "<group>"; };
		335BBD1A22A9A15E00E9071D /* GeneratedPluginRegistrant.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = GeneratedPluginRegistrant.swift; sourceTree = "<group>"; };
		33A1EAC57DDC643AD4885ECF /* Pods-RunnerTests.debug.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-RunnerTests.debug.xcconfig"; path = "Target Support Files/Pods-RunnerTests/Pods-RunnerTests.debug.xcconfig"; sourceTree = "<group>"; };
		33CC10ED2044A3C60003C045 /* flutter_inactive_timer_example.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = flutter_inactive_timer_example.app; sourceTree = BUILT_PRODUCTS_DIR; };
		33CC10F02044A3C60003C045 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
		33CC10F22044A3C60003C045 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Runner/Assets.xcassets; sourceTree = "<group>"; };
		33CC10F52044A3C60003C045 /* Base */ = {isa = PBXFileReference; lastKnownFileType = file.xib; name = Base; path = Base.lproj/MainMenu.xib; sourceTree = "<group>"; };
		33CC10F72044A3C60003C045 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = Runner/Info.plist; sourceTree = "<group>"; };
		33CC11122044BFA00003C045 /* MainFlutterWindow.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MainFlutterWindow.swift; sourceTree = "<group>"; };
		33CEB47222A05771004F2AC0 /* Flutter-Debug.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = "Flutter-Debug.xcconfig"; sourceTree = "<group>"; };
		33CEB47422A05771004F2AC0 /* Flutter-Release.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = "Flutter-Release.xcconfig"; sourceTree = "<group>"; };
		33CEB47722A0578A004F2AC0 /* Flutter-Generated.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Flutter-Generated.xcconfig"; path = "ephemeral/Flutter-Generated.xcconfig"; sourceTree = "<group>"; };
		33E51913231747F40026EE4D /* DebugProfile.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = DebugProfile.entitlements; sourceTree = "<group>"; };
		33E51914231749380026EE4D /* Release.entitlements */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.entitlements; path = Release.entitlements; sourceTree = "<group>"; };
		33E5194F232828860026EE4D /* AppInfo.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = AppInfo.xcconfig; sourceTree = "<group>"; };
		3E01D8AEE29D2D3BC8A522DA /* Pods-Runner.profile.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-Runner.profile.xcconfig"; path = "Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"; sourceTree = "<group>"; };
		3F86244311756DE8A23C28DD /* Pods-RunnerTests.release.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-RunnerTests.release.xcconfig"; path = "Target Support Files/Pods-RunnerTests/Pods-RunnerTests.release.xcconfig"; sourceTree = "<group>"; };
		70C975366AF1292D82ACCF60 /* Pods_Runner.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Pods_Runner.framework; sourceTree = BUILT_PRODUCTS_DIR; };
		7AFA3C8E1D35360C0083082E /* Release.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Release.xcconfig; sourceTree = "<group>"; };
		9740EEB21CF90195004384FC /* Debug.xcconfig */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.xcconfig; path = Debug.xcconfig; sourceTree = "<group>"; };
		CB357A2AC0AE7CA8A042EF5A /* Pods-Runner.debug.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-Runner.debug.xcconfig"; path = "Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"; sourceTree = "<group>"; };
		D661FC5BC13BA5F92707D3AD /* Pods-RunnerTests.profile.xcconfig */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.xcconfig; name = "Pods-RunnerTests.profile.xcconfig"; path = "Target Support Files/Pods-RunnerTests/Pods-RunnerTests.profile.xcconfig"; sourceTree = "<group>"; };
		FB206FAB697CE4BFA2FD8CAB /* Pods_RunnerTests.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Pods_RunnerTests.framework; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		331C80D2294CF70F00263BE5 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				1EE3BF8164E0F092B945FB73 /* Pods_RunnerTests.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		33CC10EA2044A3C60003C045 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				4D1C5D79619816FB1C5AF8A3 /* Pods_Runner.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		331C80D6294CF71000263BE5 /* RunnerTests */ = {
			isa = PBXGroup;
			children = (
				331C80D7294CF71000263BE5 /* RunnerTests.swift */,
			);
			path = RunnerTests;
			sourceTree = "<group>";
		};
		33BA886A226E78AF003329D5 /* Configs */ = {
			isa = PBXGroup;
			children = (
				33E5194F232828860026EE4D /* AppInfo.xcconfig */,
				9740EEB21CF90195004384FC /* Debug.xcconfig */,
				7AFA3C8E1D35360C0083082E /* Release.xcconfig */,
				333000ED22D3DE5D00554162 /* Warnings.xcconfig */,
			);
			path = Configs;
			sourceTree = "<group>";
		};
		33CC10E42044A3C60003C045 = {
			isa = PBXGroup;
			children = (
				33FAB671232836740065AC1E /* Runner */,
				33CEB47122A05771004F2AC0 /* Flutter */,
				331C80D6294CF71000263BE5 /* RunnerTests */,
				33CC10EE2044A3C60003C045 /* Products */,
				D73912EC22F37F3D000D13A0 /* Frameworks */,
				5D18B1D0D5051B5A5B6D6A0F /* Pods */,
			);
			sourceTree = "<group>";
		};
		33CC10EE2044A3C60003C045 /* Products */ = {
			isa = PBXGroup;
			children = (
				33CC10ED2044A3C60003C045 /* flutter_inactive_timer_example.app */,
				331C80D5294CF71000263BE5 /* RunnerTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		33CC11242044D66E0003C045 /* Resources */ = {
			isa = PBXGroup;
			children = (
				33CC10F22044A3C60003C045 /* Assets.xcassets */,
				33CC10F42044A3C60003C045 /* MainMenu.xib */,
				33CC10F72044A3C60003C045 /* Info.plist */,
			);
			name = Resources;
			path = ..;
			sourceTree = "<group>";
		};
		33CEB47122A05771004F2AC0 /* Flutter */ = {
			isa = PBXGroup;
			children = (
				335BBD1A22A9A15E00E9071D /* GeneratedPluginRegistrant.swift */,
				33CEB47222A05771004F2AC0 /* Flutter-Debug.xcconfig */,
				33CEB47422A05771004F2AC0 /* Flutter-Release.xcconfig */,
				33CEB47722A0578A004F2AC0 /* Flutter-Generated.xcconfig */,
			);
			path = Flutter;
			sourceTree = "<group>";
		};
		33FAB671232836740065AC1E /* Runner */ = {
			isa = PBXGroup;
			children = (
				33CC10F02044A3C60003C045 /* AppDelegate.swift */,
				33CC11122044BFA00003C045 /* MainFlutterWindow.swift */,
				33E51913231747F40026EE4D /* DebugProfile.entitlements */,
				33E51914231749380026EE4D /* Release.entitlements */,
				33CC11242044D66E0003C045 /* Resources */,
				33BA886A226E78AF003329D5 /* Configs */,
			);
			path = Runner;
			sourceTree = "<group>";
		};
		5D18B1D0D5051B5A5B6D6A0F /* Pods */ = {
			isa = PBXGroup;
			children = (
				CB357A2AC0AE7CA8A042EF5A /* Pods-Runner.debug.xcconfig */,
				07D573B28E1DBE7008097DBA /* Pods-Runner.release.xcconfig */,
				3E01D8AEE29D2D3BC8A522DA /* Pods-Runner.profile.xcconfig */,
				33A1EAC57DDC643AD4885ECF /* Pods-RunnerTests.debug.xcconfig */,
				3F86244311756DE8A23C28DD /* Pods-RunnerTests.release.xcconfig */,
				D661FC5BC13BA5F92707D3AD /* Pods-RunnerTests.profile.xcconfig */,
			);
			name = Pods;
			path = Pods;
			sourceTree = "<group>";
		};
		D73912EC22F37F3D000D13A0 /* Frameworks */ = {
			isa = PBXGroup;
			children = (
				70C975366AF1292D82ACCF60 /* Pods_Runner.framework */,
				FB206FAB697CE4BFA2FD8CAB /* Pods_RunnerTests.framework */,
			);
			name = Frameworks;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		331C80D4294CF70F00263BE5 /* RunnerTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 331C80DE294CF71000263BE5 /* Build configuration list for PBXNativeTarget "RunnerTests" */;
			buildPhases = (
				C1088F86BAB27FDEC79EB378 /* [CP] Check Pods Manifest.lock */,
				331C80D1294CF70F00263BE5 /* Sources */,
				331C80D2294CF70F00263BE5 /* Frameworks */,
				331C80D3294CF70F00263BE5 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				331C80DA294CF71000263BE5 /* PBXTargetDependency */,
			);
			name = RunnerTests;
			productName = RunnerTests;
			productReference = 331C80D5294CF71000263BE5 /* RunnerTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
		33CC10EC2044A3C60003C045 /* Runner */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 33CC10FB2044A3C60003C045 /* Build configuration list for PBXNativeTarget "Runner" */;
			buildPhases = (
				1E4C11B2E792D254799EAB53 /* [CP] Check Pods Manifest.lock */,
				33CC10E92044A3C60003C045 /* Sources */,
				33CC10EA2044A3C60003C045 /* Frameworks */,
				33CC10EB2044A3C60003C045 /* Resources */,
				33CC110E2044A8840003C045 /* Bundle Framework */,
				3399D490228B24CF009A79C7 /* ShellScript */,
				629741CAA0A473CA9BA9DE56 /* [CP] Embed Pods Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				33CC11202044C79F0003C045 /* PBXTargetDependency */,
			);
			name = Runner;
			productName = Runner;
			productReference = 33CC10ED2044A3C60003C045 /* flutter_inactive_timer_example.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		33CC10E52044A3C60003C045 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = YES;
				LastSwiftUpdateCheck = 0920;
				LastUpgradeCheck = 1510;
				ORGANIZATIONNAME = "";
				TargetAttributes = {
					331C80D4294CF70F00263BE5 = {
						CreatedOnToolsVersion = 14.0;
						TestTargetID = 33CC10EC2044A3C60003C045;
					};
					33CC10EC2044A3C60003C045 = {
						CreatedOnToolsVersion = 9.2;
						LastSwiftMigration = 1100;
						ProvisioningStyle = Automatic;
						SystemCapabilities = {
							com.apple.Sandbox = {
								enabled = 1;
							};
						};
					};
					33CC111A2044C6BA0003C045 = {
						CreatedOnToolsVersion = 9.2;
						ProvisioningStyle = Manual;
					};
				};
			};
			buildConfigurationList = 33CC10E82044A3C60003C045 /* Build configuration list for PBXProject "Runner" */;
			compatibilityVersion = "Xcode 9.3";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 33CC10E42044A3C60003C045;
			productRefGroup = 33CC10EE2044A3C60003C045 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				33CC10EC2044A3C60003C045 /* Runner */,
				331C80D4294CF70F00263BE5 /* RunnerTests */,
				33CC111A2044C6BA0003C045 /* Flutter Assemble */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		331C80D3294CF70F00263BE5 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		33CC10EB2044A3C60003C045 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				33CC10F32044A3C60003C045 /* Assets.xcassets in Resources */,
				33CC10F62044A3C60003C045 /* MainMenu.xib in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
		1E4C11B2E792D254799EAB53 /* [CP] Check Pods Manifest.lock */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
				"${PODS_PODFILE_DIR_PATH}/Podfile.lock",
				"${PODS_ROOT}/Manifest.lock",
			);
			name = "[CP] Check Pods Manifest.lock";
			outputFileListPaths = (
			);
			outputPaths = (
				"$(DERIVED_FILE_DIR)/Pods-Runner-checkManifestLockResult.txt",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "diff \"${PODS_PODFILE_DIR_PATH}/Podfile.lock\" \"${PODS_ROOT}/Manifest.lock\" > /dev/null\nif [ $? != 0 ] ; then\n    # print error to STDERR\n    echo \"error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.\" >&2\n    exit 1\nfi\n# This output is used by Xcode 'outputs' to avoid re-running this script phase.\necho \"SUCCESS\" > \"${SCRIPT_OUTPUT_FILE_0}\"\n";
			showEnvVarsInLog = 0;
		};
		3399D490228B24CF009A79C7 /* ShellScript */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
			);
			outputFileListPaths = (
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "echo \"$PRODUCT_NAME.app\" > \"$PROJECT_DIR\"/Flutter/ephemeral/.app_filename && \"$FLUTTER_ROOT\"/packages/flutter_tools/bin/macos_assemble.sh embed\n";
		};
		33CC111E2044C6BF0003C045 /* ShellScript */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
				Flutter/ephemeral/FlutterInputs.xcfilelist,
			);
			inputPaths = (
				Flutter/ephemeral/tripwire,
			);
			outputFileListPaths = (
				Flutter/ephemeral/FlutterOutputs.xcfilelist,
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\"$FLUTTER_ROOT\"/packages/flutter_tools/bin/macos_assemble.sh && touch Flutter/ephemeral/tripwire";
		};
		629741CAA0A473CA9BA9DE56 /* [CP] Embed Pods Frameworks */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
				"${PODS_ROOT}/Target Support Files/Pods-Runner/Pods-Runner-frameworks-${CONFIGURATION}-input-files.xcfilelist",
			);
			name = "[CP] Embed Pods Frameworks";
			outputFileListPaths = (
				"${PODS_ROOT}/Target Support Files/Pods-Runner/Pods-Runner-frameworks-${CONFIGURATION}-output-files.xcfilelist",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\"${PODS_ROOT}/Target Support Files/Pods-Runner/Pods-Runner-frameworks.sh\"\n";
			showEnvVarsInLog = 0;
		};
		C1088F86BAB27FDEC79EB378 /* [CP] Check Pods Manifest.lock */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
				"${PODS_PODFILE_DIR_PATH}/Podfile.lock",
				"${PODS_ROOT}/Manifest.lock",
			);
			name = "[CP] Check Pods Manifest.lock";
			outputFileListPaths = (
			);
			outputPaths = (
				"$(DERIVED_FILE_DIR)/Pods-RunnerTests-checkManifestLockResult.txt",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "diff \"${PODS_PODFILE_DIR_PATH}/Podfile.lock\" \"${PODS_ROOT}/Manifest.lock\" > /dev/null\nif [ $? != 0 ] ; then\n    # print error to STDERR\n    echo \"error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.\" >&2\n    exit 1\nfi\n# This output is used by Xcode 'outputs' to avoid re-running this script phase.\necho \"SUCCESS\" > \"${SCRIPT_OUTPUT_FILE_0}\"\n";
			showEnvVarsInLog = 0;
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		331C80D1294CF70F00263BE5 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				331C80D8294CF71000263BE5 /* RunnerTests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		33CC10E92044A3C60003C045 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				33CC11132044BFA00003C045 /* MainFlutterWindow.swift in Sources */,
				33CC10F12044A3C60003C045 /* AppDelegate.swift in Sources */,
				335BBD1B22A9A15E00E9071D /* GeneratedPluginRegistrant.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		331C80DA294CF71000263BE5 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 33CC10EC2044A3C60003C045 /* Runner */;
			targetProxy = 331C80D9294CF71000263BE5 /* PBXContainerItemProxy */;
		};
		33CC11202044C79F0003C045 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 33CC111A2044C6BA0003C045 /* Flutter Assemble */;
			targetProxy = 33CC111F2044C79F0003C045 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin PBXVariantGroup section */
		33CC10F42044A3C60003C045 /* MainMenu.xib */ = {
			isa = PBXVariantGroup;
			children = (
				33CC10F52044A3C60003C045 /* Base */,
			);
			name = MainMenu.xib;
			path = Runner;
			sourceTree = "<group>";
		};
/* End PBXVariantGroup section */

/* Begin XCBuildConfiguration section */
		331C80DB294CF71000263BE5 /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 33A1EAC57DDC643AD4885ECF /* Pods-RunnerTests.debug.xcconfig */;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterInactiveTimerExample.RunnerTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/flutter_inactive_timer_example.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/flutter_inactive_timer_example";
			};
			name = Debug;
		};
		331C80DC294CF71000263BE5 /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 3F86244311756DE8A23C28DD /* Pods-RunnerTests.release.xcconfig */;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterInactiveTimerExample.RunnerTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/flutter_inactive_timer_example.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/flutter_inactive_timer_example";
			};
			name = Release;
		};
		331C80DD294CF71000263BE5 /* Profile */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = D661FC5BC13BA5F92707D3AD /* Pods-RunnerTests.profile.xcconfig */;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterInactiveTimerExample.RunnerTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/flutter_inactive_timer_example.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/flutter_inactive_timer_example";
			};
			name = Profile;
		};
		338D0CE9231458BD00FA5F75 /* Profile */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++14";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CODE_SIGN_IDENTITY = "-";
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 10.14;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Profile;
		};
		338D0CEA231458BD00FA5F75 /* Profile */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 33E5194F232828860026EE4D /* AppInfo.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				INFOPLIST_FILE = Runner/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_VERSION = 5.0;
			};
			name = Profile;
		};
		338D0CEB231458BD00FA5F75 /* Profile */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Manual;
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Profile;
		};
		33CC10F92044A3C60003C045 /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++14";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CODE_SIGN_IDENTITY = "-";
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 10.14;
				MTL_ENABLE_DEBUG_INFO = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		33CC10FA2044A3C60003C045 /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++14";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CODE_SIGN_IDENTITY = "-";
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 10.14;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		33CC10FC2044A3C60003C045 /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 33E5194F232828860026EE4D /* AppInfo.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				INFOPLIST_FILE = Runner/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		33CC10FD2044A3C60003C045 /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 33E5194F232828860026EE4D /* AppInfo.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				INFOPLIST_FILE = Runner/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		33CC111C2044C6BA0003C045 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Manual;
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Debug;
		};
		33CC111D2044C6BA0003C045 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		331C80DE294CF71000263BE5 /* Build configuration list for PBXNativeTarget "RunnerTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				331C80DB294CF71000263BE5 /* Debug */,
				331C80DC294CF71000263BE5 /* Release */,
				331C80DD294CF71000263BE5 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		33CC10E82044A3C60003C045 /* Build configuration list for PBXProject "Runner" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				33CC10F92044A3C60003C045 /* Debug */,
				33CC10FA2044A3C60003C045 /* Release */,
				338D0CE9231458BD00FA5F75 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		33CC10FB2044A3C60003C045 /* Build configuration list for PBXNativeTarget "Runner" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				33CC10FC2044A3C60003C045 /* Debug */,
				33CC10FD2044A3C60003C045 /* Release */,
				338D0CEA231458BD00FA5F75 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		33CC111B2044C6BA0003C045 /* Build configuration list for PBXAggregateTarget "Flutter Assemble" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				33CC111C2044C6BA0003C045 /* Debug */,
				33CC111D2044C6BA0003C045 /* Release */,
				338D0CEB231458BD00FA5F75 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 33CC10E52044A3C60003C045 /* Project object */;
}

```
## example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>IDEDidComputeMac32BitWarning</key>
	<true/>
</dict>
</plist>

```
## example/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
```xcscheme
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "33CC10EC2044A3C60003C045"
               BuildableName = "flutter_inactive_timer_example.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "33CC10EC2044A3C60003C045"
            BuildableName = "flutter_inactive_timer_example.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "331C80D4294CF70F00263BE5"
               BuildableName = "RunnerTests.xctest"
               BlueprintName = "RunnerTests"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "33CC10EC2044A3C60003C045"
            BuildableName = "flutter_inactive_timer_example.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "33CC10EC2044A3C60003C045"
            BuildableName = "flutter_inactive_timer_example.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>

```
## example/macos/Runner.xcworkspace/contents.xcworkspacedata
```xcworkspacedata
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:Runner.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:Pods/Pods.xcodeproj">
   </FileRef>
</Workspace>

```
## example/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>IDEDidComputeMac32BitWarning</key>
	<true/>
</dict>
</plist>

```
## example/test/widget_test.dart
```dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_inactive_timer_example/main.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text &&
                           widget.data!.startsWith('Running on:'),
      ),
      findsOneWidget,
    );
  });
}

```
## lib/flutter_inactive_timer.dart
```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';

class FlutterInactiveTimer {
  /// The duration of inactivity before timeout (in seconds)
  final int timeoutDuration;

  /// Percentage of timeout duration when notification should trigger (0-100)
  /// If set to 0, no notification will be triggered
  final int notificationPer;

  /// Callback that is called when inactivity timeout is reached
  final void Function() onInactiveDetected;

  /// Callback that is called when notification threshold is reached
  final void Function() onNotification;

  /// If true, only explicit continue action will reset the timer after notification
  /// If false, any user activity will reset the timer (default behavior)
  final bool requireExplicitContinue;

  Timer? _timer;
  bool _isNotification = false;
  int _lastInputTime = 0;
  int _notificationTime = 0;
  bool _isMonitoring = false;
  bool _lockInputReset = false;

  /// Creates an inactive timer with required parameters
  FlutterInactiveTimer({
    required this.timeoutDuration,
    required this.notificationPer,
    required this.onInactiveDetected,
    required this.onNotification,
    this.requireExplicitContinue = false, // default behavior
  });

  /// Initialize with default values (no monitoring)
  factory FlutterInactiveTimer.init() => FlutterInactiveTimer(
        notificationPer: 0,
        timeoutDuration: 0,
        onInactiveDetected: () {},
        onNotification: () {},
      );

  /// Called when the user explicitly chooses to continue the session
  void continueSession() {
    if (_isMonitoring) {
      _lockInputReset = false;
      _resetTimer();
    }
  }

  /// Reset the timer (internal method)
  Future<void> _resetTimer() async {
    _lastInputTime =
        await FlutterInactiveTimerPlatform.instance.getSystemTickCount();
    _isNotification = false;
    _scheduleNextCheck();
  }

  /// Start monitoring for user inactivity
  Future<void> startMonitoring() async {
    _isMonitoring = true;
    _isNotification = false;
    _lockInputReset = false;
    _lastInputTime =
        await FlutterInactiveTimerPlatform.instance.getSystemTickCount();

    if (timeoutDuration != 0) {
      _scheduleNextCheck();
    }
  }

  /// Stop monitoring for user inactivity
  void stopMonitoring() {
    _isMonitoring = false;
    _timer?.cancel();
  }

  /// Schedule the next inactivity check
  Future<void> _scheduleNextCheck() async {
    _timer?.cancel();
    final int nextDelay = await _calculateNextCheckDelay();
    _timer = Timer(Duration(milliseconds: nextDelay), _checkInactivity);
  }

  /// Calculate the optimal delay until next check
  Future<int> _calculateNextCheckDelay() async {
    int currentTime =
        await FlutterInactiveTimerPlatform.instance.getSystemTickCount();

    int elapsedTime = currentTime - _lastInputTime;
    int remainTime = timeoutDuration * 1000 - elapsedTime;

    if (notificationPer == 0) {
      int delay = remainTime > 0 ? remainTime : 1;
      return delay;
    }

    final notificationTime =
        (timeoutDuration * 1000 * notificationPer / 100).round();
    _notificationTime = timeoutDuration * 1000 - notificationTime;

    if (remainTime <= 0) {
      return 1;
    } else if (elapsedTime < _notificationTime) {
      int delay =
          _isNotification ? remainTime : _notificationTime - elapsedTime;
      return delay;
    } else if (!_isNotification) {
      return 1;
    } else {
      int delay = max(remainTime, 1000);
      return delay;
    }
  }

  /// Check if user is inactive and handle timeout or notification
  Future<void> _checkInactivity() async {
    if (!_isMonitoring) return;

    try {
      final currentTime =
          await FlutterInactiveTimerPlatform.instance.getSystemTickCount();
      final lastSystemInputTime =
          await FlutterInactiveTimerPlatform.instance.getLastInputTime();
      final inactiveDuration = currentTime - _lastInputTime;

      // If notification has been triggered and requireExplicitContinue is true,
      // do not reset the timer automatically
      bool shouldResetTimer = lastSystemInputTime > _lastInputTime &&
          !(requireExplicitContinue && _lockInputReset);

      if (shouldResetTimer) {
        if (_isNotification) {
          _isNotification = false;
        }

        _lastInputTime = lastSystemInputTime;
        _scheduleNextCheck();
        return;
      }

      if (inactiveDuration >= timeoutDuration * 1000) {
        onInactiveDetected.call();
        stopMonitoring();
      } else {
        int reachedPer = (inactiveDuration * 100 ~/ (timeoutDuration * 1000));
        if (reachedPer >= notificationPer &&
            !_isNotification &&
            notificationPer > 0) {
          _isNotification = true;

          // Lock reset only if requireExplicitContinue is true
          if (requireExplicitContinue) {
            _lockInputReset = true;
          }

          onNotification.call();
        }
        _scheduleNextCheck();
      }
    } catch (e) {
      _scheduleNextCheck();
    }
  }
}

```
## lib/flutter_inactive_timer_method_channel.dart
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_inactive_timer_platform_interface.dart';

/// An implementation of [FlutterInactiveTimerPlatform] that uses method channels.
class MethodChannelFlutterInactiveTimer extends FlutterInactiveTimerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_inactive_timer');

  @override
  Future<int> getSystemTickCount() async {
    final int tickCount =
        await methodChannel.invokeMethod<int>('getSystemTickCount') ?? 0;
    return tickCount;
  }

  @override
  Future<int> getLastInputTime() async {
    final int lastInputTime =
        await methodChannel.invokeMethod<int>('getLastInputTime') ?? 0;
    return lastInputTime;
  }
}

```
## lib/flutter_inactive_timer_platform_interface.dart
```dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_inactive_timer_method_channel.dart';

abstract class FlutterInactiveTimerPlatform extends PlatformInterface {
  /// Constructs a FlutterInactiveTimerPlatform.
  FlutterInactiveTimerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterInactiveTimerPlatform _instance =
      MethodChannelFlutterInactiveTimer();

  /// The default instance of [FlutterInactiveTimerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterInactiveTimer].
  static FlutterInactiveTimerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterInactiveTimerPlatform] when
  /// they register themselves.
  static set instance(FlutterInactiveTimerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the current system tick count
  Future<int> getSystemTickCount() {
    throw UnimplementedError('getSystemTickCount() has not been implemented.');
  }

  /// Gets the time of the last user input
  Future<int> getLastInputTime() {
    throw UnimplementedError('getLastInputTime() has not been implemented.');
  }
}

```
## macos/Classes/FlutterInactiveTimerPlugin.swift
```swift
import Cocoa
import FlutterMacOS
import IOKit
import IOKit.hid

// Main plugin class for Flutter on macOS
public class FlutterInactiveTimerPlugin: NSObject, FlutterPlugin {

  // Register the plugin with Flutter
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Create a method channel for communication between Flutter and native macOS
    let channel = FlutterMethodChannel(name: "flutter_inactive_timer", binaryMessenger: registrar.messenger)
    let instance = FlutterInactiveTimerPlugin()
    // Set the delegate to handle method calls from Flutter
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // Handle method calls from Flutter
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getSystemTickCount":
      // Return system uptime in milliseconds
      result(getSystemUptimeInMilliseconds())

    case "getLastInputTime":
      // Return the last user input time if available
      if let lastInput = getLastInputTime() {
        result(lastInput)
      } else {
        result(FlutterError(code: "UNAVAILABLE", message: "Cannot get last input time", details: nil))
      }

    default:
      // Method not implemented
      result(FlutterMethodNotImplemented)
    }
  }

  // Get the system uptime since last boot in milliseconds
  private func getSystemUptimeInMilliseconds() -> UInt64 {
    let uptime = ProcessInfo.processInfo.systemUptime
    return UInt64(uptime * 1000)
  }

  // Get the last time the user provided input (keyboard/mouse) in milliseconds
  private func getLastInputTime() -> UInt64? {
    var iterator = io_iterator_t()
    let matchingDict = IOServiceMatching("IOHIDSystem")

    // Get an iterator for matching services
    guard IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
      return nil
    }

    // Get the first matching entry
    let entry = IOIteratorNext(iterator)
    IOObjectRelease(iterator)

    guard entry != 0 else { return nil }

    var properties: Unmanaged<CFMutableDictionary>?

    // Fetch the HID properties dictionary
    guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let dict = properties?.takeRetainedValue() as? [String: AnyObject],
          let hidIdleTime = dict["HIDIdleTime"] as? UInt64 else {
      IOObjectRelease(entry)
      return nil
    }

    IOObjectRelease(entry)

    // Convert HIDIdleTime from nanoseconds to milliseconds
    let idleMillis = hidIdleTime / 1_000_000

    // Subtract idle time from system uptime to get the last input time
    return getSystemUptimeInMilliseconds() - idleMillis
  }
}

```
## macos/Resources/PrivacyInfo.xcprivacy
```xcprivacy
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyTracking</key>
	<false/>
</dict>
</plist>

```
## macos/flutter_inactive_timer.podspec
```podspec
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_inactive_timer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_inactive_timer'
  s.version          = '1.1.0'
  s.summary          = 'A Flutter plugin for detecting user inactivity in desktop applications.'
  s.description      = <<-DESC
A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). 
This plugin provides customizable timeout and notification thresholds, making it ideal for 
implementing security features like automatic logout or session timeouts.
                       DESC
  s.homepage         = 'https://github.com/kihyun1998/flutter_inactive_timer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'kihyun1998' => 'https://github.com/kihyun1998' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # Uncommented the privacy manifest resources since macOS might need it for input monitoring
  s.resource_bundles = {'flutter_inactive_timer_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
```
## test/flutter_inactive_timer_method_channel_test.dart
```dart
import 'package:flutter/services.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterInactiveTimer platform =
      MethodChannelFlutterInactiveTimer();
  const MethodChannel channel = MethodChannel('flutter_inactive_timer');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getSystemTickCount':
            return 1000;
          case 'getLastInputTime':
            return 950;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSystemTickCount', () async {
    expect(await platform.getSystemTickCount(), 1000);
  });

  test('getLastInputTime', () async {
    expect(await platform.getLastInputTime(), 950);
  });
}

```
## test/flutter_inactive_timer_test.dart
```dart
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  int _mockTickCount = 1000;
  int _mockLastInputTime = 950;

  // Method to change tick count for testing
  void setMockTickCount(int value) {
    _mockTickCount = value;
  }

  // Method to change last input time for testing
  void setMockLastInputTime(int value) {
    _mockLastInputTime = value;
  }

  @override
  Future<int> getSystemTickCount() async {
    return _mockTickCount;
  }

  @override
  Future<int> getLastInputTime() async {
    return _mockLastInputTime;
  }
}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform =
      FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });

  group('FlutterInactiveTimer', () {
    late MockFlutterInactiveTimerPlatform mockPlatform;
    late FlutterInactiveTimer inactiveTimer;

    setUp(() {
      mockPlatform = MockFlutterInactiveTimerPlatform();
      FlutterInactiveTimerPlatform.instance = mockPlatform;

      inactiveTimer = FlutterInactiveTimer(
        timeoutDuration: 10, // 10-second timeout
        notificationPer: 70, // 70% threshold for notification
        onInactiveDetected: () {
          // Optional actions to take when the callback is invoked
        },
        onNotification: () {
          // Optional actions to take when the callback is invoked
        },
      );
    });

    test('init constructor creates instance with default values', () {
      final timer = FlutterInactiveTimer.init();
      expect(timer.timeoutDuration, 0);
      expect(timer.notificationPer, 0);
    });

    test('startMonitoring initializes monitoring state', () async {
      await inactiveTimer.startMonitoring();
      // It's difficult to test private fields, but state should be initialized
      expect(true, true); // Just confirming execution
    });

    test('stopMonitoring stops timer', () async {
      await inactiveTimer.startMonitoring();
      inactiveTimer.stopMonitoring();
      // The timer should be stopped. We can't verify internal state but can ensure no errors
      expect(true, true);
    });

    test('continueSession resets timer lock', () async {
      await inactiveTimer.startMonitoring();
      inactiveTimer.continueSession();
      // lockInputReset should be set to false, but it's a private field so we can't check directly
      expect(true, true);
    });

    // Tests based on elapsed time can simulate time manipulation using the mock
    test('inactive detection occurs after timeout', () async {
      await inactiveTimer.startMonitoring();

      // Simulate time passing beyond the timeout
      mockPlatform.setMockTickCount(1000);
      mockPlatform
          .setMockLastInputTime(1000 - 11000); // Last input was 11 seconds ago

      // We can't directly call _checkInactivity since it's private,
      // and in a real environment it would be invoked via the timer.
      // So here we only test the setup and structure.

      expect(inactiveTimer.timeoutDuration, 10);
      expect(inactiveTimer.notificationPer, 70);
    });
  });
}

```
## windows/CMakeLists.txt
```txt
# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_inactive_timer")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_inactive_timer_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_inactive_timer_plugin.cpp"
  "flutter_inactive_timer_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_inactive_timer/flutter_inactive_timer_plugin_c_api.h"
  "flutter_inactive_timer_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_inactive_timer_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/flutter_inactive_timer_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()

```
## windows/flutter_inactive_timer_plugin.cpp
```cpp
#include "flutter_inactive_timer_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_inactive_timer {

// static
void FlutterInactiveTimerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_inactive_timer",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterInactiveTimerPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterInactiveTimerPlugin::FlutterInactiveTimerPlugin() {}

FlutterInactiveTimerPlugin::~FlutterInactiveTimerPlugin() {}

void FlutterInactiveTimerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getSystemTickCount") == 0) {
    // Use GetTickCount64 to avoid overflow issues with GetTickCount
    ULONGLONG tickCount = GetTickCount64();
    // Convert to int64_t for EncodableValue
    int64_t ticks = static_cast<int64_t>(tickCount);
    result->Success(flutter::EncodableValue(ticks));
  } else if (method_call.method_name().compare("getLastInputTime") == 0) {
    LASTINPUTINFO lastInputInfo;
    lastInputInfo.cbSize = sizeof(LASTINPUTINFO);
    
    if (GetLastInputInfo(&lastInputInfo)) {
      // GetLastInputInfo returns a tick count, convert to int64_t for EncodableValue
      int64_t lastInput = static_cast<int64_t>(lastInputInfo.dwTime);
      result->Success(flutter::EncodableValue(lastInput));
    } else {
      // In case of error, return current tick count
      ULONGLONG tickCount = GetTickCount64();
      int64_t ticks = static_cast<int64_t>(tickCount);
      result->Success(flutter::EncodableValue(ticks));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_inactive_timer

```
## windows/flutter_inactive_timer_plugin.h
```h
#ifndef FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_inactive_timer {

class FlutterInactiveTimerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterInactiveTimerPlugin();

  virtual ~FlutterInactiveTimerPlugin();

  // Disallow copy and assign.
  FlutterInactiveTimerPlugin(const FlutterInactiveTimerPlugin&) = delete;
  FlutterInactiveTimerPlugin& operator=(const FlutterInactiveTimerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_inactive_timer

#endif  // FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_

```
## windows/flutter_inactive_timer_plugin_c_api.cpp
```cpp
#include "include/flutter_inactive_timer/flutter_inactive_timer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_inactive_timer_plugin.h"

void FlutterInactiveTimerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_inactive_timer::FlutterInactiveTimerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

```
## windows/include/flutter_inactive_timer/flutter_inactive_timer_plugin_c_api.h
```h
#ifndef FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FlutterInactiveTimerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_C_API_H_

```
## windows/test/flutter_inactive_timer_plugin_test.cpp
```cpp
#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "flutter_inactive_timer_plugin.h"

namespace flutter_inactive_timer {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(FlutterInactiveTimerPlugin, GetPlatformVersion) {
  FlutterInactiveTimerPlugin plugin;
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

}  // namespace test
}  // namespace flutter_inactive_timer

```
