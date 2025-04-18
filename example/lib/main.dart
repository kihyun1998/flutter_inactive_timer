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

  // 사용자 설정 가능한 값
  int _timeoutDuration = 15; // 기본값 15초
  int _notificationPercent = 70; // 기본값 70%
  bool _requireExplicitContinue = true; // 명시적 계속 필요

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

    // 다이얼로그 표시
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
                  // _startMonitoring(); // 선택적으로 다시 모니터링 시작
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
    // Snackbar로 경고 표시
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Warning: Your session will expire soon due to inactivity!'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Continue Session',
            onPressed: () {
              // 사용자가 버튼을 누르면 명시적으로 세션 계속
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

    // 모니터링 시작 알림
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

  // 설정 변경 시 타이머 재설정
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

            // 타임아웃 설정
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

            // 데모 설명
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

            // 제어 버튼
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
    // 정리 작업
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
  // 좌측 타이머
  FlutterInactiveTimer? _leftTimer;
  bool _isLeftMonitoring = false;
  String _leftStatus = 'Not monitoring';
  int _leftTimeoutDuration = 10; // 10초
  int _leftNotificationPercent = 50; // 50%

  // 우측 타이머
  FlutterInactiveTimer? _rightTimer;
  bool _isRightMonitoring = false;
  String _rightStatus = 'Not monitoring';
  int _rightTimeoutDuration = 20; // 20초
  int _rightNotificationPercent = 80; // 80%

  @override
  void initState() {
    super.initState();
    _setupTimers();
  }

  void _setupTimers() {
    // 좌측 타이머 설정
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

    // 우측 타이머 설정
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

  // 좌측 타이머 시작
  void _startLeftTimer() async {
    if (_leftTimer == null) return;

    await _leftTimer!.startMonitoring();

    setState(() {
      _leftStatus = 'Monitoring...';
      _isLeftMonitoring = true;
    });
  }

  // 좌측 타이머 중지
  void _stopLeftTimer() {
    if (_leftTimer == null) return;

    _leftTimer!.stopMonitoring();

    setState(() {
      _leftStatus = 'Stopped';
      _isLeftMonitoring = false;
    });
  }

  // 좌측 타이머 설정 업데이트
  void _updateLeftTimer() {
    if (_isLeftMonitoring) {
      _stopLeftTimer();
    }

    _setupTimers(); // 양쪽 타이머 모두 재설정

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Left timer settings updated'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 우측 타이머 시작
  void _startRightTimer() async {
    if (_rightTimer == null) return;

    await _rightTimer!.startMonitoring();

    setState(() {
      _rightStatus = 'Monitoring...';
      _isRightMonitoring = true;
    });
  }

  // 우측 타이머 중지
  void _stopRightTimer() {
    if (_rightTimer == null) return;

    _rightTimer!.stopMonitoring();

    setState(() {
      _rightStatus = 'Stopped';
      _isRightMonitoring = false;
    });
  }

  // 우측 타이머 설정 업데이트
  void _updateRightTimer() {
    if (_isRightMonitoring) {
      _stopRightTimer();
    }

    _setupTimers(); // 양쪽 타이머 모두 재설정

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
                // 좌측 타이머
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

                          // 좌측 타이머 설정 슬라이더
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

                          // 업데이트 버튼
                          Center(
                            child: ElevatedButton(
                              onPressed: _updateLeftTimer,
                              child: const Text('Update Settings'),
                            ),
                          ),

                          const Spacer(),

                          // 제어 버튼
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

                // 우측 타이머
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

                          // 우측 타이머 설정 슬라이더
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

                          // 업데이트 버튼
                          Center(
                            child: ElevatedButton(
                              onPressed: _updateRightTimer,
                              child: const Text('Update Settings'),
                            ),
                          ),

                          const Spacer(),

                          // 제어 버튼
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
