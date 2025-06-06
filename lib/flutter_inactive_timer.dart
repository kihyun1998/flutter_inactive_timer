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
