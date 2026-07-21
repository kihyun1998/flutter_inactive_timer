import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';

import 'idle_source_demo.dart';

void main() {
  runApp(const MyApp());
}

/// How the Single-mode demo schedules its notification, mapped to a
/// [NotificationTrigger] (or `null`) when the timer is built.
enum NotifyMode { percent, before, none }

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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inactive Timer Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Single Mode', icon: Icon(Icons.timer)),
              Tab(text: 'Multi Mode', icon: Icon(Icons.splitscreen)),
              Tab(text: 'Idle Source', icon: Icon(Icons.speed)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SingleModeDemo(),
            MultiModeDemo(),
            IdleSourceDemo(),
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

  // A UI-owned ticker that pulls remaining() once a second for the countdown.
  // The plugin keeps no ticker of its own — this is the "pull" pattern.
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  // User-configurable values
  int _timeoutDuration = 15; // default: 15 seconds
  NotifyMode _notifyMode = NotifyMode.percent;
  int _notificationPercent = 70; // used when _notifyMode == percent
  int _notifyBeforeSeconds = 5; // used when _notifyMode == before
  bool _requireExplicitContinue = true; // Require explicit continue

  @override
  void initState() {
    super.initState();
    _setupInactivityTimer();
  }

  /// Builds the [NotificationTrigger] for the selected [NotifyMode], or `null`
  /// for no notification. The before value is clamped shorter than the timeout,
  /// which [NotifyBefore] requires.
  NotificationTrigger? _buildTrigger() {
    switch (_notifyMode) {
      case NotifyMode.none:
        return null;
      case NotifyMode.percent:
        return _notificationPercent == 0
            ? null
            : NotifyAtPercent(_notificationPercent);
      case NotifyMode.before:
        final secs = _notifyBeforeSeconds.clamp(1, _timeoutDuration - 1);
        return NotifyBefore(Duration(seconds: secs));
    }
  }

  /// A human-readable description of the current notification setting.
  String get _notifyDescription {
    switch (_notifyMode) {
      case NotifyMode.none:
        return 'None (timeout only)';
      case NotifyMode.percent:
        return _notificationPercent == 0
            ? 'None (0%)'
            : 'At $_notificationPercent% of timeout';
      case NotifyMode.before:
        final secs = _notifyBeforeSeconds.clamp(1, _timeoutDuration - 1);
        return '$secs seconds before timeout';
    }
  }

  void _setupInactivityTimer() {
    // Dispose the previous timer before replacing it so its timer callback
    // doesn't keep the old instance alive.
    _inactivityTimer?.dispose();
    _inactivityTimer = FlutterInactiveTimer(
      timeoutDuration: Duration(seconds: _timeoutDuration),
      notification: _buildTrigger(),
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

  /// Pulls `remaining()` every second to drive the countdown label.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final left = await _inactivityTimer?.remaining() ?? Duration.zero;
      if (mounted) setState(() => _remaining = left);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _remaining = Duration.zero);
  }

  /// Formats a duration as MM:SS for the countdown display.
  String _formatMMSS(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startMonitoring() async {
    if (_inactivityTimer == null) return;

    await _inactivityTimer!.startMonitoring();
    if (!mounted) return;

    setState(() {
      _status = 'Monitoring active';
      _isMonitoring = true;
    });
    _startTicker();

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
    _stopTicker();

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
                    if (_isMonitoring) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Logs out in ${_formatMMSS(_remaining)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _remaining.inSeconds <= 5
                              ? Colors.red
                              : Colors.teal,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Current Settings:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Timeout: $_timeoutDuration seconds'),
                    Text('Notification: $_notifyDescription'),
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
                    const Text('Notification Mode:'),
                    const SizedBox(height: 4),
                    SegmentedButton<NotifyMode>(
                      segments: const [
                        ButtonSegment(
                            value: NotifyMode.percent, label: Text('Percent')),
                        ButtonSegment(
                            value: NotifyMode.before, label: Text('Before')),
                        ButtonSegment(
                            value: NotifyMode.none, label: Text('None')),
                      ],
                      selected: {_notifyMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _notifyMode = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Percent mode: fire at a percentage of the timeout.
                    if (_notifyMode == NotifyMode.percent) ...[
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
                    ],
                    // Before mode: fire a fixed lead time before the timeout.
                    if (_notifyMode == NotifyMode.before) ...[
                      Text(
                          'Notify $_notifyBeforeSeconds seconds before timeout'),
                      Slider(
                        value: _notifyBeforeSeconds
                            .clamp(1, _timeoutDuration - 1)
                            .toDouble(),
                        min: 1,
                        // Must stay shorter than the timeout (NotifyBefore rule).
                        max: (_timeoutDuration - 1).toDouble(),
                        label: '$_notifyBeforeSeconds seconds',
                        onChanged: (value) {
                          setState(() {
                            _notifyBeforeSeconds = value.round();
                          });
                        },
                      ),
                    ],
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
                    Text('• A live MM:SS countdown driven by remaining()'),
                    Text('• A Snackbar warning when the notification fires'),
                    Text('• A Dialog when inactive timeout is reached'),
                    Text(
                        '• Notification by percent, seconds-before-timeout, or none'),
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
    // Cancel the UI ticker and permanently tear down the timer so both can be
    // garbage collected.
    _ticker?.cancel();
    _inactivityTimer?.dispose();
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

  // Right timer — demonstrates the "N seconds before timeout" mode.
  FlutterInactiveTimer? _rightTimer;
  bool _isRightMonitoring = false;
  String _rightStatus = 'Not monitoring';
  int _rightTimeoutDuration = 20; // 20 sec
  int _rightNotifyBeforeSeconds = 5; // notify 5s before timeout

  @override
  void initState() {
    super.initState();
    _setupTimers();
  }

  void _setupTimers() {
    // Dispose any previous timers before replacing them.
    _leftTimer?.dispose();
    _rightTimer?.dispose();

    // Configure left timer
    _leftTimer = FlutterInactiveTimer(
      timeoutDuration: Duration(seconds: _leftTimeoutDuration),
      notification: _leftNotificationPercent == 0
          ? null
          : NotifyAtPercent(_leftNotificationPercent),
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
      onActive: () {
        setState(() {
          _leftStatus = 'Monitoring...';
        });
      },
    );

    // Configure right timer — notify a fixed lead time before the timeout.
    _rightTimer = FlutterInactiveTimer(
      timeoutDuration: Duration(seconds: _rightTimeoutDuration),
      notification: NotifyBefore(
        Duration(
          seconds:
              _rightNotifyBeforeSeconds.clamp(1, _rightTimeoutDuration - 1),
        ),
      ),
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
      onActive: () {
        setState(() {
          _rightStatus = 'Monitoring...';
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
                            'Left Timer (percent)',
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
                            'Right Timer (before)',
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

                          Text(
                              'Notify: $_rightNotifyBeforeSeconds s before timeout'),
                          Slider(
                            value: _rightNotifyBeforeSeconds
                                .clamp(1, _rightTimeoutDuration - 1)
                                .toDouble(),
                            min: 1,
                            max: (_rightTimeoutDuration - 1).toDouble(),
                            label: '$_rightNotifyBeforeSeconds s',
                            onChanged: (value) {
                              setState(() {
                                _rightNotifyBeforeSeconds = value.round();
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
    _leftTimer?.dispose();
    _rightTimer?.dispose();
    super.dispose();
  }
}
